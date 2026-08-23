module Payroll
  class FullAndFinalPreview
    Result = Struct.new(
      :salary_days,
      :earned_salary,
      :leave_encashment_days,
      :leave_encashment,
      :warnings,
      keyword_init: true
    )

    def initialize(employee:, last_working_date:)
      @employee = employee
      @last_working_date = last_working_date.to_date
      @tenant = employee.tenant
      @warnings = []
    end

    def call
      salary_days, earned_salary = salary_preview
      leave_days, leave_amount = leave_preview

      Result.new(
        salary_days: salary_days,
        earned_salary: earned_salary,
        leave_encashment_days: leave_days,
        leave_encashment: leave_amount,
        warnings: @warnings
      )
    end

    private

    def salary_preview
      if salary_already_paid?
        @warnings << "Regular payroll already includes this employee for the last-working-date month; salary defaults to zero."
        return [ 0, 0 ]
      end

      salary = salary_at_last_working_date
      unless salary
        @warnings << "No salary assignment covers the last working date; enter earned salary manually."
        return [ payable_days, 0 ]
      end

      setting = @tenant.payroll_setting
      unless setting
        @warnings << "Payroll settings are missing; enter earned salary manually."
        return [ payable_days, 0 ]
      end

      breakup = Salary::CtcBreakupCalculator.call(
        annual_ctc: salary.annual_ctc,
        salary_structure: salary.salary_structure,
        payroll_setting: setting,
        professional_tax_slabs: [],
        apply_employer_pf_carve: nil
      )
      day_rate = breakup.gross_monthly.to_d / @last_working_date.end_of_month.day
      [ payable_days, (day_rate * payable_days).round(2) ]
    rescue => e
      @warnings << "Salary preview could not be calculated: #{e.message}"
      [ payable_days, 0 ]
    end

    def leave_preview
      fy = financial_year_for(@last_working_date)
      balances = LeaveBalance.joins(:leave_type)
        .where(employee: @employee, financial_year: fy)
        .where(leave_types: { carry_forward: true, is_paid: true, is_active: true })

      days = balances.sum(:remaining_days).to_d
      return [ 0, 0 ] unless days.positive?

      amount = Leave::EncashmentCalculator.new(
        employee: @employee,
        number_of_days: days,
        as_of: @last_working_date
      ).call
      [ days, amount ]
    rescue Leave::EncashmentCalculator::NoSalaryError => e
      @warnings << "Leave encashment needs review: #{e.message}"
      [ days || 0, 0 ]
    end

    def salary_already_paid?
      Payslip.joins(:payroll_run)
        .where(employee: @employee, month: @last_working_date.month, year: @last_working_date.year)
        .where(payroll_runs: { run_type: "regular", status: %w[processing processed under_review approved paid] })
        .exists?
    end

    def salary_at_last_working_date
      @employee.employee_salaries
        .where("effective_from <= ?", @last_working_date)
        .where("effective_to IS NULL OR effective_to >= ?", @last_working_date)
        .order(effective_from: :desc)
        .first
    end

    def payable_days
      period_start = @last_working_date.beginning_of_month
      employment_start = [ period_start, @employee.joining_date ].compact.max
      return 0 if employment_start > @last_working_date

      (@last_working_date - employment_start).to_i + 1
    end

    def financial_year_for(date)
      date.month >= 4 ? "#{date.year}-#{(date.year + 1).to_s.last(2)}" : "#{date.year - 1}-#{date.year.to_s.last(2)}"
    end
  end
end
