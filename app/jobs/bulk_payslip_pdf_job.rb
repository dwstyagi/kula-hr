class BulkPayslipPdfJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :default
  retry_on StandardError, attempts: 2

  def perform(payroll_run_id)
    payroll_run = PayrollRun.find(payroll_run_id)

    ActsAsTenant.with_tenant(payroll_run.tenant) do
      dir = pdf_dir(payroll_run)
      FileUtils.mkdir_p(dir)

      # Phase 1: write each payslip PDF to an individual tmp file
      step :generate_pdfs, cursor: 0 do |s|
        payroll_run.payslips
                   .where("id > ?", s.cursor)
                   .includes(:employee, :line_items, :tenant)
                   .find_each do |payslip|
          path = dir.join(pdf_filename(payslip, payroll_run))
          File.binwrite(path, Payroll::PayslipPdfGenerator.new(payslip: payslip).call)
          s.set!(payslip.id)
        end
      end

      # Phase 2: zip all generated PDFs into a single archive
      step :zip_pdfs do
        zip_path = Rails.root.join("tmp", zip_filename(payroll_run))
        Zip::OutputStream.open(zip_path.to_s) do |zip|
          Dir[dir.join("*.pdf")].sort.each do |pdf_path|
            zip.put_next_entry(File.basename(pdf_path))
            zip.write(File.binread(pdf_path))
          end
        end
        Rails.logger.info "Bulk payslip ZIP generated: #{zip_path}"
      end

      # Phase 3: remove the individual PDF tmp files
      step :cleanup do
        FileUtils.rm_rf(dir)
      end
    end
  end

  private

  def pdf_dir(payroll_run)
    Rails.root.join("tmp", "payslips_#{payroll_run.id}")
  end

  def pdf_filename(payslip, payroll_run)
    "#{payslip.employee.employee_code}_#{payslip.employee.full_name.gsub(/\s+/, '_')}_#{payroll_run.period_label.gsub(' ', '_')}.pdf"
  end

  def zip_filename(payroll_run)
    "payslips_#{payroll_run.id}_#{payroll_run.month}_#{payroll_run.year}.zip"
  end
end
