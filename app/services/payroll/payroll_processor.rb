module Payroll
  class PayrollProcessor
    ProcessingResult = Struct.new(
      :payroll_run, :processed, :skipped, :errors,
      keyword_init: true
    )

    def initialize(payroll_run:)
      @run       = payroll_run
      @tenant    = payroll_run.tenant
      @setting   = payroll_run.tenant.payroll_setting
      @processed = []
      @skipped   = []
      @errors    = []
    end

    def call
      @run.start_processing!

      employees = eligible_employees
      @run.update!(total_employees: employees.count)

      ActsAsTenant.with_tenant(@tenant) do
        employees.find_each.with_index(1) do |employee, index|
          process_employee(employee)
          update_progress(index)
        end
      end

      finalize
    rescue => e
      @run.update!(notes: "Processing failed: #{e.message}")
      raise
    end

    private

    # ── Employee eligibility ───────────────────────────────────────────────────

    def eligible_employees
      month_start = Date.new(@run.year, @run.month, 1)
      month_end   = month_start.end_of_month

      ActsAsTenant.with_tenant(@tenant) do
        Employee.where(
          "employment_status = ? OR (employment_status = ? AND exit_date BETWEEN ? AND ?)",
          "active", "exited", month_start, month_end
        )
      end
    end

    # ── Per-employee processing ────────────────────────────────────────────────

    def process_employee(employee)
      result = Payroll::SalaryCalculator.new(
        employee:        employee,
        payroll_run:     @run,
        payroll_setting: @setting
      ).call

      create_payslip(result)
      @processed << employee.id

    rescue Payroll::SalaryCalculator::CalculationError => e
      record_skip(employee, e.message)
    rescue => e
      record_skip(employee, "Unexpected error: #{e.message}")
    end

    def record_skip(employee, reason)
      @skipped << employee.id
      @errors  << { employee_id: employee.id, name: employee.full_name, error: reason }
      Rails.logger.warn("[PayrollProcessor] Skipped #{employee.full_name}: #{reason}")
    end

    # ── Payslip creation ───────────────────────────────────────────────────────

    def create_payslip(result)
      payslip = @run.payslips.create!(
        tenant:             @tenant,
        employee:           result.employee,
        month:              @run.month,
        year:               @run.year,
        gross_pay:          result.gross_pay,
        total_deductions:   result.total_deductions,
        net_pay:            result.net_pay,
        employer_pf:        result.employer_costs[:pf],
        employer_esi:       result.employer_costs[:esi],
        total_working_days: result.attendance[:working_days],
        paid_days:          result.attendance[:paid_days],
        lop_days:           result.attendance[:lop_days]
      )

      create_line_items(payslip, result)
    end

    def create_line_items(payslip, result)
      sort = 0

      # Earnings — store both prorated and full amount
      result.earnings.each do |name, amount|
        payslip.line_items.create!(
          component_name: name,
          component_type: "earning",
          amount:         amount,
          full_amount:    result.full_earnings[name],
          sort_order:     (sort += 1),
          category:       "fixed"
        )
      end

      # Deductions — no full_amount (deductions are on prorated base)
      result.deductions.each do |name, amount|
        payslip.line_items.create!(
          component_name: name,
          component_type: "deduction",
          amount:         amount,
          sort_order:     (sort += 1),
          category:       "statutory"
        )
      end
    end

    # ── Progress + finalise ────────────────────────────────────────────────────

    def update_progress(count)
      @run.update_column(:processed_employees, count)
      broadcast_progress
    end

    def broadcast_progress
      Turbo::StreamsChannel.broadcast_replace_to(
        "payroll_run_#{@run.id}",
        target:  "payroll_progress",
        partial: "admin/payroll_runs/progress",
        locals:  { payroll_run: @run }
      )
    end

    def finalize
      @run.update!(
        total_gross:         @run.payslips.sum(:gross_pay),
        total_deductions:    @run.payslips.sum(:total_deductions),
        total_net_pay:       @run.payslips.sum(:net_pay),
        total_employer_cost: @run.payslips.sum(:employer_pf) + @run.payslips.sum(:employer_esi)
      )

      @run.finish_processing!

      ProcessingResult.new(
        payroll_run: @run,
        processed:   @processed,
        skipped:     @skipped,
        errors:      @errors
      )
    end
  end
end
