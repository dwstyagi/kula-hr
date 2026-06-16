module Attendance
  # Generates (or refreshes) AttendanceSummary records for all active employees
  # in a given month/year. Existing draft records are updated; locked records
  # are left untouched. Call this after the month ends when leave data is final.
  class SummaryGenerator
    def initialize(month:, year:, tenant:)
      @month  = month
      @year   = year
      @tenant = tenant
    end

    def call
      # acts_as_tenant already scopes Employee to the current tenant
      Employee.where(employment_status: %w[active probation]).find_each do |employee|
        # Working days are location-aware: each location can have its own holidays.
        # Memoize per location so we query holidays once per distinct location.
        working_days = working_days_for(employee.work_location_id)

        paid_leave_days = leave_days_for(employee, paid_only: true)
        lop_leave_days  = leave_days_for(employee, lop_only: true)

        # Default days_present: assume full attendance minus known leaves
        default_present = [ working_days - paid_leave_days, 0 ].max

        summary = AttendanceSummary.find_or_initialize_by(
          tenant:   @tenant,
          employee: employee,
          month:    @month,
          year:     @year
        )

        # Skip already-locked records
        next if summary.persisted? && summary.locked?

        summary.assign_attributes(
          total_working_days: working_days,
          approved_leaves:    paid_leave_days,
          lop_leaves:         lop_leave_days,
          days_present:       summary.new_record? ? default_present : summary.days_present,
          half_days:          summary.new_record? ? 0 : summary.half_days
        )
        summary.save!
      end
    end

    private

    def working_days_for(work_location_id)
      @working_days_by_location ||= {}
      @working_days_by_location[work_location_id] ||= WorkingDaysCalculator.new(
        month: @month, year: @year, tenant: @tenant, work_location: work_location_id
      ).call
    end

    def leave_days_for(employee, paid_only: false, lop_only: false)
      start_date = Date.new(@year, @month, 1)
      end_date   = start_date.end_of_month

      scope = employee.leave_requests.approved
                      .where("from_date <= ? AND to_date >= ?", end_date, start_date)

      if lop_only
        scope = scope.joins(:leave_type).where(leave_types: { is_paid: false })
      elsif paid_only
        scope = scope.joins(:leave_type).where(leave_types: { is_paid: true })
      end

      scope.sum do |req|
        overlap_start = [ req.from_date, start_date ].max
        overlap_end   = [ req.to_date,   end_date ].min
        business_days(overlap_start, overlap_end)
      end
    end

    def business_days(from, to)
      (from..to).count { |d| !d.saturday? && !d.sunday? }
    end
  end
end
