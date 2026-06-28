module Payroll
  # Single source of truth for "who is eligible for payroll this month, and is
  # each of them ready to be paid?". Consumed by:
  #   - Admin::PayrollRunsController#new  → live readiness panel
  #   - PayrollRun#attendance_must_be_locked → hard creation gate
  #   - PayrollProcessor#eligible_employees  → who actually gets processed
  #
  # Keeping the eligibility definition here guarantees the new-page panel, the
  # creation error, and the processor can never disagree about who is in scope.
  class ReadinessCheck
    # Per-employee verdict.
    EmployeeStatus = Struct.new(:employee, :has_attendance, :has_salary, keyword_init: true) do
      def ready? = has_attendance && has_salary

      # Active/probation employees with no locked attendance are the ONLY thing
      # that blocks PayrollRun creation (matches the historical hard gate).
      # Resigned/terminated with no attendance are merely skipped at processing.
      def blocks_creation?
        !has_attendance && %w[active probation].include?(employee.employment_status)
      end

      def reasons
        r = []
        r << "no locked attendance" unless has_attendance
        r << "no salary assigned"   unless has_salary
        r
      end
    end

    Result = Struct.new(:statuses, keyword_init: true) do
      def eligible_count = statuses.size
      def ready          = statuses.select(&:ready?)
      def ready_count    = ready.size

      # Hard blockers — creation is refused while any of these exist.
      def blocking       = statuses.select(&:blocks_creation?)
      def can_create?    = blocking.empty?

      # Not ready, but won't block creation → they get silently skipped at
      # processing unless HR fixes them. This is the list we surface up front.
      def will_skip      = statuses.reject(&:ready?).reject(&:blocks_creation?)
    end

    # Same eligibility definition the processor uses: active + probation, plus
    # anyone resigned/terminated whose last working day falls in this month.
    def self.eligible_employees(month:, year:, tenant:)
      month_start = Date.new(year.to_i, month.to_i, 1)
      month_end   = month_start.end_of_month

      ActsAsTenant.with_tenant(tenant) do
        Employee.where(
          "employment_status IN (?) OR " \
          "(employment_status IN (?) AND last_working_date BETWEEN ? AND ?)",
          %w[active probation], %w[resigned terminated], month_start, month_end
        )
      end
    end

    def initialize(month:, year:, tenant:)
      @month  = month.to_i
      @year   = year.to_i
      @tenant = tenant
    end

    def call
      # Guard against blank/invalid periods (e.g. while other validations on the
      # PayrollRun are still failing) — Date.new would otherwise raise.
      return Result.new(statuses: []) unless (1..12).cover?(@month) && @year.positive?

      ActsAsTenant.with_tenant(@tenant) do
        employees = self.class.eligible_employees(month: @month, year: @year, tenant: @tenant).to_a
        emp_ids   = employees.map(&:id)

        locked_ids = AttendanceSummary
          .where(employee_id: emp_ids, month: @month, year: @year, status: :locked)
          .pluck(:employee_id).to_set

        salaried_ids = EmployeeSalary
          .where(employee_id: emp_ids, effective_to: nil)
          .pluck(:employee_id).to_set

        statuses = employees.map do |e|
          EmployeeStatus.new(
            employee:       e,
            has_attendance: locked_ids.include?(e.id),
            has_salary:     salaried_ids.include?(e.id)
          )
        end

        Result.new(statuses: statuses)
      end
    end
  end
end
