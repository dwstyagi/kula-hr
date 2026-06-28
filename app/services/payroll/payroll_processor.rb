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
      # Guard: if the job is retried and the run is already processing, continue
      @run.start_processing! if @run.may_start_processing?
      return unless @run.processing?

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
      # Single source of truth — see Payroll::ReadinessCheck.
      Payroll::ReadinessCheck.eligible_employees(
        month: @run.month, year: @run.year, tenant: @tenant
      )
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
      ActiveRecord::Base.transaction do
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
        apply_encashments(payslip, result.employee)
      end
    end

    # Pays out any approved-but-unpaid leave encashments for this employee as a
    # separate (non-prorated) earning line item, then marks each request paid and
    # links it to this payslip so it is never paid twice. Option A: encashment is
    # not run through PF/ESI/PT/TDS — see docs/gaps.md #3 for the tax follow-up.
    def apply_encashments(payslip, employee)
      requests = LeaveEncashmentRequest.payable.where(employee: employee).includes(:leave_type).to_a
      return if requests.empty?

      now      = Time.current
      max_sort = payslip.line_items.maximum(:sort_order) || 0

      items = requests.map.with_index(1) do |req, i|
        {
          payslip_id:     payslip.id,
          component_name: "Leave Encashment (#{req.leave_type.code})",
          component_type: "earning",
          amount:         req.encashment_amount,
          full_amount:    req.encashment_amount,
          sort_order:     max_sort + i,
          category:       "variable",
          created_at:     now,
          updated_at:     now
        }
      end

      PayslipLineItem.insert_all!(items)
      requests.each { |req| req.update!(status: :paid, payslip: payslip) }
      payslip.recalculate_totals!
    end

    def create_line_items(payslip, result)
      now  = Time.current
      sort = 0

      # Earnings — store both prorated and full amount
      line_items = result.earnings.map do |name, amount|
        {
          payslip_id:     payslip.id,
          component_name: name,
          component_type: "earning",
          amount:         amount,
          full_amount:    result.full_earnings[name],
          sort_order:     (sort += 1),
          category:       "fixed",
          created_at:     now,
          updated_at:     now
        }
      end

      # Deductions — no full_amount (deductions are on prorated base)
      line_items += result.deductions.map do |name, amount|
        {
          payslip_id:     payslip.id,
          component_name: name,
          component_type: "deduction",
          amount:         amount,
          full_amount:    nil,
          sort_order:     (sort += 1),
          category:       "statutory",
          created_at:     now,
          updated_at:     now
        }
      end

      PayslipLineItem.insert_all!(line_items) if line_items.any?
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
