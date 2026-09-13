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
    EmployeeStatus = Struct.new(:employee, :has_attendance, :has_salary,
                                 :current_salary, :salary_recently_changed,
                                 keyword_init: true) do
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

    # Counts describe the whole group; iteration is a bounded detail preview.
    class StatusList
      include Enumerable
      def initialize(scope, checker)
        @scope, @checker = scope, checker
      end
      def size = @size ||= @scope.count
      def empty? = size.zero?
      def any?(&block) = block ? super(&block) : !empty?
      def each(&block)
        return enum_for(:each) unless block
        @checker.statuses_for(@scope.limit(50).preload(:current_employee_salary).to_a).each(&block)
      end
    end

    Result = Struct.new(:statuses, :ready, :blocking, :will_skip, :variance_flags, keyword_init: true) do
      def eligible_count = statuses.size
      def ready_count = ready.size
      def can_create? = blocking.empty?
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
      unless (1..12).cover?(@month) && @year.positive?
        return Result.new(statuses: [], ready: [], blocking: [], will_skip: [], variance_flags: [])
      end
      ActsAsTenant.with_tenant(@tenant) do
        scope = self.class.eligible_employees(month: @month, year: @year, tenant: @tenant)
        salary = EmployeeSalary.where(effective_to: nil).select(:employee_id)
        ready = scope.where(id: locked_scope).where(id: salary)
        blocking = scope.where(employment_status: %w[active probation]).where.not(id: locked_scope)
        skip = scope.where.not(id: ready.select(:id)).where.not(id: blocking.select(:id))
        variance = ready.where(id: EmployeeSalary.where(effective_to: nil)
          .where("effective_from >= ?", Date.new(@year, @month, 1).prev_month).select(:employee_id))
        Result.new(statuses: StatusList.new(scope, self), ready: StatusList.new(ready, self),
          blocking: StatusList.new(blocking, self), will_skip: StatusList.new(skip, self),
          variance_flags: StatusList.new(variance, self))
      end
    end

    def statuses_for(employees)
      ActsAsTenant.with_tenant(@tenant) do
        locked = locked_scope.where(employee_id: employees.map(&:id)).pluck(:employee_id).to_set
        employees.map do |employee|
          salary = employee.current_salary
          EmployeeStatus.new(employee: employee, has_attendance: locked.include?(employee.id),
            has_salary: salary.present?, current_salary: salary,
            salary_recently_changed: salary.present? && salary.effective_from >= Date.new(@year, @month, 1).prev_month)
        end
      end
    end

    private

    def locked_scope
      AttendanceSummary.where(month: @month, year: @year, status: :locked).select(:employee_id)
    end
  end
end
