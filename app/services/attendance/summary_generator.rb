module Attendance
  class SummaryGenerator
    def initialize(month:, year:, tenant:)
      @month, @year, @tenant = month, year, tenant
    end

    def call
      month_start = Date.new(@year, @month, 1)
      month_end   = month_start.end_of_month

      ActsAsTenant.with_tenant(@tenant) do
        # Locked employees are excluded before any leave lookups or calculations.
        locked = AttendanceSummary.for_month(@month, @year).locked.select(:employee_id)
        Employee.payable_in(month_start).where.not(id: locked)
          .find_in_batches(batch_size: 100) do |employees|
          ids = employees.map(&:id)
          summaries = AttendanceSummary.for_month(@month, @year).where(employee_id: ids).index_by(&:employee_id)
          leaves = LeaveRequest.approved.where(employee_id: ids)
            .where("from_date <= ? AND to_date >= ?", month_end, month_start)
            .includes(:leave_type).group_by(&:employee_id)
          now = Time.current
          records = employees.filter_map do |employee|
            window = employee.employment_window(month_start, month_end)
            next unless window

            calendar = working_dates_for(employee.work_location_id)
            working  = calendar.size
            employed = calendar.count { |day| window.cover?(day) }
            not_employed = working - employed

            # Leave is counted on the same working-day calendar as the month
            # total (week-off pattern + holidays), and only while employed.
            paid, lop = 0, 0
            Array(leaves[employee.id]).each do |request|
              days = calendar.count { |day| day.between?(request.from_date, request.to_date) && window.cover?(day) }
              request.leave_type.is_paid? ? paid += days : lop += days
            end

            summary = summaries[employee.id]
            present = summary ? summary.days_present : [ employed - paid, 0 ].max
            half_days = summary ? summary.half_days : 0
            absent = [ employed - present - half_days * 0.5 - paid - lop, 0 ].max
            { tenant_id: @tenant.id, employee_id: employee.id, month: @month, year: @year,
              status: AttendanceSummary.statuses[:draft], total_working_days: working,
              non_employment_days: not_employed,
              approved_leaves: paid, lop_leaves: lop, days_present: present, half_days: half_days,
              unapproved_absences: absent, lop_days: absent + lop, paid_days: [ employed - absent - lop, 0 ].max,
              created_at: summary&.created_at || now, updated_at: now }
          end
          # A concurrent lock must win over generation, including a lock taken
          # after the initial employee selection. Existing manual attendance wins too.
          updates = %w[total_working_days non_employment_days approved_leaves lop_leaves updated_at].map do |column|
            "#{column} = EXCLUDED.#{column}"
          end
          employed_sql = "(EXCLUDED.total_working_days - EXCLUDED.non_employment_days)"
          absent_sql = "GREATEST(#{employed_sql} - attendance_summaries.days_present - attendance_summaries.half_days * 0.5 - EXCLUDED.approved_leaves - EXCLUDED.lop_leaves, 0)"
          updates += [ "unapproved_absences = #{absent_sql}", "lop_days = #{absent_sql} + EXCLUDED.lop_leaves",
                       "paid_days = GREATEST(#{employed_sql} - (#{absent_sql}) - EXCLUDED.lop_leaves, 0)" ]
          AttendanceSummary.upsert_all(records, unique_by: :idx_att_sum_emp_month_year,
            on_duplicate: Arel.sql("#{updates.join(', ')} WHERE attendance_summaries.status = 0")) if records.any?
        end
      end
    end

    private

    def working_dates_for(location_id)
      @working_dates_by_location ||= {}
      @working_dates_by_location[location_id] ||= WorkingDaysCalculator.new(
        month: @month, year: @year, tenant: @tenant, work_location: location_id
      ).working_dates
    end
  end
end
