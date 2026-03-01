class BulkPayslipPdfJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 2

  def perform(payroll_run_id)
    payroll_run = PayrollRun.find(payroll_run_id)

    ActsAsTenant.with_tenant(payroll_run.tenant) do
      zip_path = Payroll::BulkPayslipPdfGenerator.new(payroll_run: payroll_run).call
      Rails.logger.info "Bulk payslip ZIP generated: #{zip_path}"
    end
  end
end
