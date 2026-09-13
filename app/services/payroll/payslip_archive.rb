require "digest"
module Payroll
  class PayslipArchive
    def self.root = Rails.root.join("tmp", "payslip_archives")
    def self.version(run)
      employees = Employee.where(id: run.payslips.select(:employee_id))
      year = run.month >= 4 ? run.year : run.year - 1
      history = Payslip.where(employee_id: employees.select(:id))
        .where("year > ? OR (year = ? AND month >= 4)", year, year)
        .where("year < ? OR (year = ? AND month <= ?)", run.year, run.year, run.month)
      items = PayslipLineItem.where(payslip_id: history.select(:id))
      records = [ run.attributes, run.tenant.attributes, run.tenant.payroll_setting&.attributes, PayslipPdfDocument::TEMPLATE_VERSION ]
      [ employees, EmployeeSalary.where(employee_id: employees.select(:id)), history, items, Department.all, Designation.all, FullAndFinalSettlement.where(payroll_run_id: run.id) ].each do |scope|
        records << scope.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(updated_at)"))
      end
      records << history.pick(Arel.sql("SUM(gross_pay)"), Arel.sql("SUM(net_pay)"))
      records << items.sum(:amount)
      Digest::SHA256.hexdigest(records.to_json)
    end
    def self.path(run, version) = root.join("#{run.tenant_id}-#{run.id}-#{version}.zip")
    def self.ready?(path) = File.file?(path) && File.mtime(path) > 1.day.ago
    def self.cleanup
      root.glob("*.{zip,part}").each { |path| File.delete(path) if File.mtime(path) < 1.day.ago }
    end
  end
end
