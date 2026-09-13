module Payroll
  # All inputs are scoped to one run and a bounded employee batch. No global cache.
  class BatchInputs
    attr_reader :attendance, :declarations, :ytd_tds, :pt_slabs

    def initialize(employees:, payroll_run:)
      tenant = payroll_run.tenant
      month, year = payroll_run.month, payroll_run.year
      fy_year = month >= 4 ? year : year - 1
      fy = "#{fy_year}-#{(fy_year + 1).to_s.last(2)}"
      ids = employees.map(&:id)

      ActsAsTenant.with_tenant(tenant) do
        employees.each { |employee| employee.association(:tenant).target = tenant }
        ActiveRecord::Associations::Preloader.new(records: employees,
          associations: { current_employee_salary: { salary_structure: { salary_structure_components: :salary_component } } }).call
        @attendance = AttendanceSummary.where(employee_id: ids, month: month, year: year).index_by(&:employee_id)
        @declarations = TaxDeclaration.where(employee_id: ids, financial_year: fy)
          .includes(:investment_declarations).index_by(&:employee_id)
        @pt_slabs = ProfessionalTaxSlab.order(:id).to_a
        @ytd_tds = PayslipLineItem.joins(payslip: :payroll_run)
          .where(payslips: { employee_id: ids }, payroll_runs: { status: %w[approved paid] }, component_name: "TDS")
          .where("(payslips.year > :fy) OR (payslips.year = :fy AND payslips.month >= 4)", fy: fy_year)
          .where("(payslips.year < :year) OR (payslips.year = :year AND payslips.month < :month)", year: year, month: month)
          .group("payslips.employee_id").sum(:amount)
      end
    end
  end
end
