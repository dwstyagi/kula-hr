require "zip"

class Payroll::BulkPayslipPdfGenerator
  def initialize(payroll_run:)
    @payroll_run = payroll_run
  end

  # Returns the path to the generated ZIP file
  def call
    zip_path = Rails.root.join("tmp", "payslips_#{@payroll_run.id}_#{@payroll_run.month}_#{@payroll_run.year}.zip")

    Zip::OutputStream.open(zip_path.to_s) do |zip|
      @payroll_run.payslips
                  .includes(:employee, :line_items, :tenant)
                  .find_each do |payslip|
        pdf_data = Payroll::PayslipPdfGenerator.new(payslip: payslip).call
        filename = "#{payslip.employee.employee_code}_#{payslip.employee.full_name.gsub(/\s+/, '_')}_#{@payroll_run.period_label.gsub(' ', '_')}.pdf"
        zip.put_next_entry(filename)
        zip.write(pdf_data)
      end
    end

    zip_path
  end
end
