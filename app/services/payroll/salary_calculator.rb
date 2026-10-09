module Payroll
  class SalaryCalculator
    # Returned to PayrollProcessor — everything needed to create a Payslip
    SalaryResult = Struct.new(
      :employee,
      :earnings,          # { "Basic" => 31817, "HRA" => 15909, ... } (prorated)
      :full_earnings,     # { "Basic" => 33333, "HRA" => 16667, ... } (before proration)
      :gross_pay,
      :deductions,        # { "PF" => 1800, "PT" => 200, "TDS" => 1452 }
      :total_deductions,
      :net_pay,
      :employer_costs,    # { pf: 1800, esi: 0 }
      :attendance,        # { working_days: 22, paid_days: 21, lop_days: 1, proration_factor: 0.9545 }
      :proration_factor,
      :non_taxable_components, # earning names the salary structure marks non-taxable
      keyword_init: true
    )

    # Raised when we cannot compute salary for an employee (skipped by PayrollProcessor)
    class CalculationError < StandardError; end

    def initialize(employee:, payroll_run:, payroll_setting:, inputs: nil)
      @inputs      = inputs
      @employee    = employee
      @run         = payroll_run
      @setting     = payroll_setting
      @month       = payroll_run.month
      @year        = payroll_run.year
    end

    def call
      attendance       = fetch_attendance
      proration        = attendance[:proration_factor]

      full_earnings    = fetch_earnings
      # CTC-inclusive model: structurally carve the employer PF charges out of
      # Special Allowance (full basis), so they prorate with everything else.
      apply_employer_pf_carve!(full_earnings) if @setting.employer_pf_in_ctc?

      prorated_earnings = prorate(full_earnings, proration)
      gross            = prorated_earnings.values.sum.round(2)

      pf_result  = calculate_pf(prorated_earnings)
      esi_result = calculate_esi(gross)
      pt_result  = calculate_pt(gross)
      tds_result = calculate_tds(prorated_earnings, full_earnings, pf_result)

      deductions = build_deductions(pf_result, esi_result, pt_result, tds_result)
      total_deductions = deductions.values.sum
      net_pay          = [ gross - total_deductions, 0 ].max.round(2)

      SalaryResult.new(
        employee:          @employee,
        earnings:          prorated_earnings,
        full_earnings:     full_earnings,
        gross_pay:         gross,
        deductions:        deductions,
        total_deductions:  total_deductions,
        net_pay:           net_pay,
        employer_costs:    {
          pf:    pf_result.employer_pf,
          esi:   esi_result.employer_amount,
          admin: pf_result.admin_charge,
          edli:  pf_result.edli_charge
        },
        attendance:        attendance,
        proration_factor:  proration,
        non_taxable_components: @non_taxable_components.to_a
      )
    end

    private

    # ── Step 1: Attendance ─────────────────────────────────────────────────────

    def fetch_attendance
      summary = @inputs ? @inputs.attendance[@employee.id] : AttendanceSummary.locked.find_by(
        employee: @employee, month: @month, year: @year
      )

      unless summary
        raise CalculationError,
          "No attendance summary (locked) for #{@employee.full_name} (#{@month}/#{@year})"
      end

      lop = Attendance::LopCalculator.new(attendance_summary: summary)

      {
        working_days:      summary.total_working_days,
        paid_days:         summary.paid_days,
        lop_days:          lop.lop_days,
        proration_factor:  lop.proration_factor
      }
    end

    # ── Step 2: Earnings ───────────────────────────────────────────────────────

    def fetch_earnings
      employee_salary = @employee.current_salary
      raise CalculationError, "No salary assigned for #{@employee.full_name}" unless employee_salary

      result = Salary::CtcBreakupCalculator.call(
        annual_ctc:              employee_salary.annual_ctc,
        salary_structure:        employee_salary.salary_structure,
        payroll_setting:         @setting,
        professional_tax_slabs:  [],   # PT handled separately via ProfessionalTaxCalculator
        apply_employer_pf_carve: false, # we carve here, proration-aware (see #call)
        pf_wage_ceiling:         pf_wage_ceiling
      )

      @non_taxable_components = employee_salary.salary_structure.salary_structure_components
        .select { |ssc| ssc.salary_component.earning? && !ssc.salary_component.taxable? }
        .map { |ssc| ssc.salary_component.name }.to_set

      # Convert LineItem array → { "Basic" => 33333, "HRA" => 16667, ... }
      result.earnings.each_with_object({}) do |line_item, hash|
        hash[line_item.name] = line_item.monthly.to_f.round(2)
      end
    end

    # Reduce Special Allowance by the (full-basis) employer PF + admin + EDLI so
    # the employee bears them. Mutates the earnings hash in place.
    def apply_employer_pf_carve!(earnings)
      pf = Statutory::PfCalculator.new(
        basic:    earnings["Basic"] || 0,
        da:       earnings["DA"] || earnings["Dearness Allowance"] || 0,
        setting:  @setting,
        employee: @employee,
        wage_ceiling: pf_wage_ceiling
      ).call
      carve = (pf.employer_pf + pf.admin_charge + pf.edli_charge).to_f
      return if carve <= 0

      key = earnings.key?("Special Allowance") ? "Special Allowance" :
              (earnings.except("Basic", "HRA").max_by { |_, v| v }&.first)
      return unless key

      earnings[key] = [ earnings[key] - carve, 0 ].max.round(2)
    end

    def prorate(earnings, factor)
      return earnings if factor >= 1.0

      earnings.transform_values { |amount| (amount * factor).round(2) }
    end

    # ── Step 3: Deductions ─────────────────────────────────────────────────────

    def calculate_pf(prorated_earnings)
      basic = prorated_earnings["Basic"] || 0
      da    = prorated_earnings["DA"] || prorated_earnings["Dearness Allowance"] || 0

      Statutory::PfCalculator.new(
        basic:    basic,
        da:       da,
        setting:  @setting,
        employee: @employee,
        wage_ceiling: pf_wage_ceiling
      ).call
    end

    def calculate_esi(gross)
      Statutory::EsiCalculator.new(gross: gross, setting: @setting, continuing_coverage: esi_continuing_coverage?).call
    end

    # Covered earlier in the current ESI contribution period (Apr–Sep / Oct–Mar).
    def esi_continuing_coverage?
      covered = @inputs ? @inputs.esi_covered : ActsAsTenant.with_tenant(@employee.tenant) {
        Payroll::BatchInputs.esi_covered(employee_ids: [ @employee.id ], month: @month, year: @year)
      }
      covered.include?(@employee.id)
    end

    def calculate_pt(gross)
      Statutory::ProfessionalTaxCalculator.new(
        gross:    gross,
        setting:  @setting,
        employee: @employee,
        month:    @month,
        slabs:    @inputs&.pt_slabs
      ).call
    end

    # Annual taxable income is projected from what has actually been paid this
    # financial year, plus this month, plus a full month for every month the
    # employee is still expected to work. A mid-year joiner is therefore taxed
    # on the months they work, not on twelve, and bonus/off-cycle pay already
    # paid is included.
    def calculate_tds(prorated_earnings, full_earnings, pf_result)
      return Statutory::TdsCalculator::ZERO_RESULT unless @setting.tds_enabled?

      ytd          = ytd_totals
      months_ahead = remaining_employment_months
      full_pf      = full_month_employee_pf(full_earnings)

      projected_income = ytd.taxable_income + taxable_total(prorated_earnings) +
                         taxable_total(full_earnings) * months_ahead
      projected_pf     = ytd.employee_pf + pf_result.employee_pf + full_pf * months_ahead

      Statutory::TdsCalculator.new(
        employee:           @employee,
        annual_gross:       projected_income.round(2),
        monthly_basic:      prorated_earnings["Basic"] || 0,
        monthly_hra:        prorated_earnings["HRA"] || 0,
        annual_employee_pf: projected_pf,
        financial_year:     current_fy,
        month:              @month,
        remaining_months:   months_ahead + 1,
        declaration:        @inputs ? @inputs.declarations[@employee.id] : :load,
        ytd_tds_deducted:   ytd.tds
      ).call
    end

    def taxable_total(earnings)
      earnings.sum { |name, amount| @non_taxable_components.include?(name) ? 0 : amount }.to_d
    end

    def full_month_employee_pf(full_earnings)
      calculate_pf(full_earnings).employee_pf
    end

    def ytd_totals
      return @inputs.ytd_for(@employee.id) if @inputs

      ActsAsTenant.with_tenant(@employee.tenant) do
        Payroll::BatchInputs.ytd_totals(employee_ids: [ @employee.id ], month: @month, year: @year)
          .fetch(@employee.id, Payroll::BatchInputs::NO_YTD)
      end
    end

    # Months after this one, within the financial year, that the employee is
    # expected to be paid for. A known last working date ends the projection.
    def remaining_employment_months
      last_position = 12
      if (lwd = @employee.last_working_date)
        fy_start = Date.new(FinancialYear.start_year(Date.new(@year, @month, 1)), 4, 1)
        if lwd < fy_start
          last_position = 0
        elsif lwd < fy_start.next_year
          last_position = fy_position(lwd.month)
        end
      end
      [ last_position - fy_position(@month), 0 ].max
    end

    def fy_position(month) = FinancialYear.position(month)

    # ── Helpers ────────────────────────────────────────────────────────────────

    def pf_wage_ceiling
      @pf_wage_ceiling ||= Statutory::PfWageCeiling.for_month(@month, @year)
    end

    def build_deductions(pf, esi, pt, tds)
      {
        "PF"               => pf.employee_pf,
        "ESI"              => esi.employee_amount,
        "Professional Tax" => pt.amount,
        "TDS"              => tds.monthly_tds
      }.reject { |_, v| v.zero? }
    end

    # FY string: April 2026 → "2026-27",  March 2026 → "2025-26"
    def current_fy
      FinancialYear.for_period(@month, @year)
    end
  end
end
