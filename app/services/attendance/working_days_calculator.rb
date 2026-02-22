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
    def initialize(month:, year:, tenant:)
      @month   = month
      @year    = year
      @pattern = tenant.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
    end

    def call
      start_date = Date.new(@year, @month, 1)
      end_date   = start_date.end_of_month

      (start_date..end_date).count { |date| working_day?(date) }
    end

    private

    def working_day?(date)
      case @pattern
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
