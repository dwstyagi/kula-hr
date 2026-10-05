module Payroll
  # All inputs are scoped to one run and a bounded employee batch. No global cache.
  class BatchInputs
    # Amounts already paid this financial year, before the run's month, on
    # approved or paid payslips (regular and off-cycle runs alike).
    Ytd = Struct.new(:tds, :taxable_income, :employee_pf)
    NO_YTD = Ytd.new(0.to_d, 0.to_d, 0.to_d).freeze

    attr_reader :attendance, :declarations, :pt_slabs, :esi_covered

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
        # Only locked attendance is payable — the same rule ReadinessCheck uses.
        @attendance = AttendanceSummary.locked.where(employee_id: ids, month: month, year: year).index_by(&:employee_id)
        @declarations = TaxDeclaration.effective_for_tds.where(employee_id: ids, financial_year: fy)
          .includes(:investment_declarations).index_by(&:employee_id)
        @pt_slabs = ProfessionalTaxSlab.order(:id).to_a
        @ytd = self.class.ytd_totals(employee_ids: ids, month: month, year: year)
        @esi_covered = self.class.esi_covered(employee_ids: ids, month: month, year: year)
      end
    end

    def ytd_for(employee_id) = @ytd.fetch(employee_id, NO_YTD)

    # Kept for callers that only need TDS.
    def ytd_tds = @ytd.transform_values(&:tds)

    # One grouped query: TDS deducted, taxable earnings paid and employee PF
    # deducted so far this financial year, per employee. Call inside the
    # tenant scope.
    def self.ytd_totals(employee_ids:, month:, year:)
      fy_year = month >= 4 ? year : year - 1
      PayslipLineItem.joins(payslip: :payroll_run)
        .where(payslips: { employee_id: employee_ids }, payroll_runs: { status: %w[approved paid] })
        .where("(payslips.year > :fy) OR (payslips.year = :fy AND payslips.month >= 4)", fy: fy_year)
        .where("(payslips.year < :year) OR (payslips.year = :year AND payslips.month < :month)", year: year, month: month)
        .group("payslips.employee_id")
        .pluck(
          "payslips.employee_id",
          Arel.sql("COALESCE(SUM(CASE WHEN payslip_line_items.component_type = 'deduction' AND payslip_line_items.component_name = 'TDS' THEN payslip_line_items.amount END), 0)"),
          Arel.sql("COALESCE(SUM(CASE WHEN payslip_line_items.component_type = 'earning' AND payslip_line_items.taxable THEN payslip_line_items.amount END), 0)"),
          Arel.sql("COALESCE(SUM(CASE WHEN payslip_line_items.component_type = 'deduction' AND payslip_line_items.component_name = 'PF' THEN payslip_line_items.amount END), 0)")
        )
        .to_h { |id, tds, taxable, pf| [ id, Ytd.new(tds.to_d, taxable.to_d, pf.to_d) ] }
    end

    # ESI contribution periods run April–September and October–March. An
    # employee who had ESI deducted earlier in the current period stays covered
    # until the period ends, even if a raise takes gross above the ceiling.
    def self.esi_covered(employee_ids:, month:, year:)
      period_start_month = month >= 4 && month <= 9 ? 4 : 10
      period_start_year  = month <= 3 ? year - 1 : year
      return Set.new if month == period_start_month

      PayslipLineItem.joins(payslip: :payroll_run)
        .where(payslips: { employee_id: employee_ids }, payroll_runs: { status: %w[processed under_review approved paid] })
        .where(component_type: "deduction", component_name: "ESI")
        .where("(payslips.year > :py) OR (payslips.year = :py AND payslips.month >= :pm)", py: period_start_year, pm: period_start_month)
        .where("(payslips.year < :year) OR (payslips.year = :year AND payslips.month < :month)", year: year, month: month)
        .distinct.pluck("payslips.employee_id").to_set
    end
  end
end
