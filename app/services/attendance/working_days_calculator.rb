module Attendance
  # Calculates the number of working days in a given month for a tenant,
  # based on the tenant's PayrollSetting#week_off_pattern.
  #
  # Usage:
  #   Attendance::WorkingDaysCalculator.new(month: 3, year: 2026, tenant: tenant).call
  #   # => 22
  #
  # Patterns:
  #   all_saturdays_sundays     — Sat + Sun off (~22 days/month)
  #   alternate_saturdays_sundays — 2nd & 4th Sat + every Sun off (~24 days/month)
  #   only_sundays              — Only Sun off (~26 days/month)
  class WorkingDaysCalculator
    # work_location: the WorkLocation (or its id) whose holidays apply. When nil,
    # only company-wide holidays are subtracted. Pass an employee's work location
    # to get a location-accurate working-day count for multi-state companies.
    def initialize(month:, year:, tenant:, work_location: nil)
      @month            = month
      @year             = year
      @tenant           = tenant
      @work_location_id = work_location.respond_to?(:id) ? work_location.id : work_location
      @pattern          = tenant.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
    end

    def call
      start_date = Date.new(@year, @month, 1)
      end_date   = start_date.end_of_month

      (start_date..end_date).count do |date|
        self.class.working_day?(date, @pattern) && !holiday_dates.include?(date)
      end
    end

    private

    # Active holidays that apply to the configured work location (company-wide
    # holidays plus that location's own), within the month, as a Set of dates.
    # Holidays falling on a week-off are already excluded by #working_day?,
    # so they are never double-counted.
    def holiday_dates
      @holiday_dates ||= @tenant.holidays.active
                                .applicable_to(@work_location_id)
                                .where(date: Date.new(@year, @month, 1)..Date.new(@year, @month, 1).end_of_month)
                                .pluck(:date)
                                .to_set
    end

    def self.working_day?(date, pattern)
      case pattern
      when "all_saturdays_sundays"
        !date.saturday? && !date.sunday?

      when "alternate_saturdays_sundays"
        return false if date.sunday?
        return true  unless date.saturday?
        # 1st and 3rd Saturdays are working; 2nd and 4th are off
        week_number = (date.day - 1) / 7 + 1
        [ 1, 3 ].include?(week_number)

      when "only_sundays"
        !date.sunday?

      else
        !date.saturday? && !date.sunday?
      end
    end
  end
end
