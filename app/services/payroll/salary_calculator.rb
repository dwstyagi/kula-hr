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
      keyword_init: true
    )

    # Raised when we cannot compute salary for an employee (skipped by PayrollProcessor)
    class CalculationError < StandardError; end

    def initialize(employee:, payroll_run:, payroll_setting:)
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
      tds_result = calculate_tds(gross, prorated_earnings)

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
        proration_factor:  proration
      )
    end

    private

    # ── Step 1: Attendance ─────────────────────────────────────────────────────

    def fetch_attendance
      summary = AttendanceSummary.find_by(
        employee: @employee, month: @month, year: @year
      )

      unless summary
        raise CalculationError,
          "No attendance summary for #{@employee.full_name} (#{@month}/#{@year})"
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
        apply_employer_pf_carve: false # we carve here, proration-aware (see #call)
      )

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
        employee: @employee
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
        employee: @employee
      ).call
    end

    def calculate_esi(gross)
      Statutory::EsiCalculator.new(gross: gross, setting: @setting).call
    end

    def calculate_pt(gross)
      Statutory::ProfessionalTaxCalculator.new(
        gross:    gross,
        setting:  @setting,
        employee: @employee,
        month:    @month
      ).call
    end

    def calculate_tds(gross, prorated_earnings)
      Statutory::TdsCalculator.new(
        employee:         @employee,
        annual_gross:     annualized_gross(gross),
        monthly_basic:    prorated_earnings["Basic"] || 0,
        monthly_hra:      prorated_earnings["HRA"] || 0,
        financial_year:   current_fy,
        month:            @month,
        ytd_tds_deducted: ytd_tds_deducted
      ).call
    end

    # ── Helpers ────────────────────────────────────────────────────────────────

    def build_deductions(pf, esi, pt, tds)
      {
        "PF"               => pf.employee_pf,
        "ESI"              => esi.employee_amount,
        "Professional Tax" => pt.amount,
        "TDS"              => tds.monthly_tds
      }.reject { |_, v| v.zero? }
    end

    # Project monthly gross to full financial year
    # e.g. March gross × 12 (simplification — treats every month as equal)
    def annualized_gross(monthly_gross)
      (monthly_gross * 12).round(2)
    end

    # FY string: April 2026 → "2026-27",  March 2026 → "2025-26"
    def current_fy
      if @month >= 4
        "#{@year}-#{(@year + 1).to_s.last(2)}"
      else
        "#{@year - 1}-#{@year.to_s.last(2)}"
      end
    end

    # Sum TDS from all approved payslips this employee had in the current FY
    # so TdsCalculator can spread remaining tax over remaining months
    def ytd_tds_deducted
      fy_start_month, fy_start_year = @month >= 4 ? [ 4, @year ] : [ 4, @year - 1 ]

      ActsAsTenant.with_tenant(@employee.tenant) do
        Payslip
          .joins(:payroll_run)
          .joins("INNER JOIN payslip_line_items ON payslip_line_items.payslip_id = payslips.id")
          .where(employee: @employee)
          .where(payslip_line_items: { component_name: "TDS" })
          .where(
            "(payslips.year > :fy_year) OR (payslips.year = :fy_year AND payslips.month >= :fy_month)",
            fy_year: fy_start_year, fy_month: fy_start_month
          )
          .where(
            "(payslips.year < :cur_year) OR (payslips.year = :cur_year AND payslips.month < :cur_month)",
            cur_year: @year, cur_month: @month
          )
          .where(payroll_runs: { status: %w[approved paid] })
          .sum("payslip_line_items.amount")
      end
    end
  end
end
