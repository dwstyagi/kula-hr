module Attendance
  class SummaryGenerator
    def initialize(month:, year:, tenant:)
      @month, @year, @tenant = month, year, tenant
    end

    def call
      ActsAsTenant.with_tenant(@tenant) do
        # Locked employees are excluded before any leave lookups or calculations.
        locked = AttendanceSummary.for_month(@month, @year).locked.select(:employee_id)
        Employee.where(employment_status: %w[active probation]).where.not(id: locked)
          .find_in_batches(batch_size: 100) do |employees|
          ids = employees.map(&:id)
          summaries = AttendanceSummary.for_month(@month, @year).where(employee_id: ids).index_by(&:employee_id)
          start_date = Date.new(@year, @month, 1)
          leaves = LeaveRequest.approved.where(employee_id: ids)
            .where("from_date <= ? AND to_date >= ?", start_date.end_of_month, start_date)
            .includes(:leave_type).group_by(&:employee_id)
          now = Time.current
          records = employees.map do |employee|
            summary = summaries[employee.id]
            paid, lop = 0, 0
            Array(leaves[employee.id]).each do |request|
              first = [ request.from_date, start_date ].max
              last = [ request.to_date, start_date.end_of_month ].min
              days = (first..last).count { |day| !day.saturday? && !day.sunday? }
              request.leave_type.is_paid? ? paid += days : lop += days
            end
            working = working_days_for(employee.work_location_id)
            present = summary ? summary.days_present : [ working - paid, 0 ].max
            half_days = summary ? summary.half_days : 0
            absent = [ working - present - half_days * 0.5 - paid - lop, 0 ].max
            { tenant_id: @tenant.id, employee_id: employee.id, month: @month, year: @year,
              status: AttendanceSummary.statuses[:draft], total_working_days: working,
              approved_leaves: paid, lop_leaves: lop, days_present: present, half_days: half_days,
              unapproved_absences: absent, lop_days: absent + lop, paid_days: [ working - absent - lop, 0 ].max,
              created_at: summary&.created_at || now, updated_at: now }
          end
          # A concurrent lock must win over generation, including a lock taken
          # after the initial employee selection. Existing manual attendance wins too.
          updates = %w[total_working_days approved_leaves lop_leaves updated_at].map do |column|
            "#{column} = EXCLUDED.#{column}"
          end
          absent_sql = "GREATEST(EXCLUDED.total_working_days - attendance_summaries.days_present - attendance_summaries.half_days * 0.5 - EXCLUDED.approved_leaves - EXCLUDED.lop_leaves, 0)"
          updates += [ "unapproved_absences = #{absent_sql}", "lop_days = #{absent_sql} + EXCLUDED.lop_leaves",
                       "paid_days = GREATEST(EXCLUDED.total_working_days - (#{absent_sql}) - EXCLUDED.lop_leaves, 0)" ]
          AttendanceSummary.upsert_all(records, unique_by: :idx_att_sum_emp_month_year,
            on_duplicate: Arel.sql("#{updates.join(', ')} WHERE attendance_summaries.status = 0")) if records.any?
        end
      end
    end

    private

    def working_days_for(location_id)
      @working_days_by_location ||= {}
      @working_days_by_location[location_id] ||= WorkingDaysCalculator.new(
        month: @month, year: @year, tenant: @tenant, work_location: location_id
      ).call
    end
  end
end
