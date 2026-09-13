class BulkPayslipPdfJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  queue_as :default
  retry_on StandardError, attempts: 2
  def perform(payroll_run_id, version = nil, dispatch_id: nil)
    file = nil
    run = ActsAsTenant.without_tenant { PayrollRun.find_by(id: payroll_run_id) }
    unless run
      JobDispatch.where(id: dispatch_id).delete_all
      return
    end
    ActsAsTenant.with_tenant(run.tenant) do
      version ||= Payroll::PayslipArchive.version(run)
      path = Payroll::PayslipArchive.path(run, version)
      if Payroll::PayslipArchive.version(run) == version && !Payroll::PayslipArchive.ready?(path)
        FileUtils.mkdir_p(Payroll::PayslipArchive.root)
        file = Tempfile.new([ "archive", ".part" ], Payroll::PayslipArchive.root)
        file.close
        Zip::OutputStream.open(file.path) do |zip|
          run.payslips.find_in_batches(batch_size: 50) do |payslips|
            Payroll::PayslipPdfData.preload(payslips)
            totals = Payroll::PayslipPdfData.ytd(employee_ids: payslips.map(&:employee_id), month: run.month, year: run.year)
            payslips.each do |payslip|
              zip.put_next_entry("#{payslip.id}-#{payslip.employee.employee_code.gsub(/[^a-zA-Z0-9_-]/, '_')}.pdf")
              zip.write(Payroll::PayslipPdfDocument.call(payslip: payslip, ytd: totals[payslip.employee_id]))
            end
          end
        end
        File.rename(file.path, path) if Payroll::PayslipArchive.version(run.reload) == version
      end
      JobDispatch.where(id: dispatch_id).delete_all
      Payroll::PayslipArchive.cleanup
    end
  ensure
    file&.close!
  end
end
