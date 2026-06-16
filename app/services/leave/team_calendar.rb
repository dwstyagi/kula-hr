module Leave
  # Builds the data for a read-only monthly team leave calendar: a grid of
  # employees (rows) × days of the month (columns), with each cell describing
  # whether that employee is on approved or pending leave that day.
  #
  # Week-offs (per the tenant's pattern) and company-wide holidays are flagged
  # at the column level for shading. Location-specific holidays are intentionally
  # not shaded per-row in this version — they remain an employee-level concern.
  #
  # Usage:
  #   cal = Leave::TeamCalendar.new(employees: scope, month: 6, year: 2026, tenant: tenant)
  #   cal.days  # => [DayMeta, ...] one per calendar day
  #   cal.rows  # => [[employee, { Date => Cell }], ...]
  class TeamCalendar
    Cell = Struct.new(:status, :leave_code, :leave_name, keyword_init: true)

    DayMeta = Struct.new(:date, :week_off, :holiday_name, keyword_init: true) do
      def non_working?
        week_off || holiday_name.present?
      end
    end

    def initialize(employees:, month:, year:, tenant:)
      @employees  = employees.to_a
      @month      = month
      @year       = year
      @tenant     = tenant
      @start_date = Date.new(year, month, 1)
      @end_date   = @start_date.end_of_month
    end

    def days
      @days ||= (@start_date..@end_date).map do |date|
        DayMeta.new(
          date:         date,
          week_off:     !Attendance::WorkingDaysCalculator.working_day?(date, pattern),
          holiday_name: company_holiday_names[date]
        )
      end
    end

    # [[employee, { Date => Cell }], ...]
    def rows
      @rows ||= @employees.map { |employee| [ employee, cells_for(employee) ] }
    end

    def empty?
      @employees.empty?
    end

    private

    def pattern
      @pattern ||= @tenant.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
    end

    def company_holiday_names
      @company_holiday_names ||= @tenant.holidays.active.company_wide
                                        .where(date: @start_date..@end_date)
                                        .pluck(:date, :name).to_h
    end

    def leave_requests_by_employee
      @leave_requests_by_employee ||= LeaveRequest
        .where(employee_id: @employees.map(&:id))
        .where(status: [ :approved, :pending ])
        .where("from_date <= ? AND to_date >= ?", @end_date, @start_date)
        .includes(:leave_type)
        .group_by(&:employee_id)
    end

    def cells_for(employee)
      cells = {}
      Array(leave_requests_by_employee[employee.id]).each do |req|
        overlap_start = [ req.from_date, @start_date ].max
        overlap_end   = [ req.to_date,   @end_date ].min

        (overlap_start..overlap_end).each do |date|
          # Approved wins over pending when an employee has overlapping requests.
          next if cells[date]&.status == "approved"

          cells[date] = Cell.new(
            status:     req.status,
            leave_code: req.leave_type.code,
            leave_name: req.leave_type.name
          )
        end
      end
      cells
    end
  end
end
