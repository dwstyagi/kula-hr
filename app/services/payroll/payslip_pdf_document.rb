require "digest"

module Payroll
  class PayslipPdfDocument
    # Include template and asset contents so deployments invalidate old renders.
    TEMPLATE_VERSION = Digest::SHA256.hexdigest(
      [ Rails.root.join("app/services/payroll/payslip_pdf_generator.rb"),
        *Rails.root.glob("app/assets/fonts/*.ttf"), Rails.root.join("app/assets/images/payslip_seal.png") ]
        .map { |path| Digest::SHA256.file(path).hexdigest }.join
    ).freeze

    def self.call(payslip:, ytd: nil)
      PayslipPdfData.preload([ payslip ])
      totals = ytd || PayslipPdfData.ytd(employee_ids: [ payslip.employee_id ], month: payslip.month, year: payslip.year)[payslip.employee_id]
      employee, tenant = payslip.employee, payslip.tenant
      records = [ payslip, payslip.payroll_run, payslip.full_and_final_settlement,
        employee, employee.department, employee.designation, employee.current_salary,
        tenant, tenant.payroll_setting ]
      fingerprint = Digest::SHA256.hexdigest([
        TEMPLATE_VERSION, records.map { |record| record&.attributes },
        payslip.line_items.sort_by(&:id).map(&:attributes), totals
      ].to_json)
      Rails.cache.fetch("payslip_pdf/#{tenant.id}/#{payslip.id}/#{fingerprint}", expires_in: 1.day, compress: true) do
        PayslipPdfGenerator.new(payslip: payslip, ytd: totals).call
      end
    end
  end
end
