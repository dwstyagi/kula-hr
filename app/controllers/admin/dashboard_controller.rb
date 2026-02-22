module Admin
  class DashboardController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      @total_employees = Employee.count
      @active_employees = Employee.active.count
      @probation_employees = Employee.probation.count
      @resigned_employees = Employee.resigned.count

      # Department distribution
      @department_data = Employee.active.joins(:department)
                                    .group("departments.name")
                                    .count

      # Gender distribution
      @gender_data = Employee.active.group(:gender).count

      # Employment status distribution
      @status_data = Employee.group(:employment_status).count

      # Monthly hires trend (last 6 months)
      # Note: group_by_month is from groupdate gem
      @hiring_trend = Employee.active
                              .where(joining_date: 6.months.ago.beginning_of_month..Date.current)
                              .group_by_month(:joining_date, format: "%b %Y")
                              .count

      # Top departments by employee count
      @top_departments = Employee.active.joins(:department)
                                      .group("departments.name")
                                      .order("count_all DESC")
                                      .limit(5)
                                      .count

      # Average tenure calculation
      current_date = Date.current
      @avg_tenure = Employee.active.average(
        "EXTRACT(YEAR FROM AGE('#{current_date}', joining_date)) * 12 + EXTRACT(MONTH FROM AGE('#{current_date}', joining_date)) / 12.0"
      ) || 0

      # Salary range distribution
      if Employee.active.joins(:employee_salaries).exists?
        @salary_ranges = Employee.active.joins(:employee_salaries)
                                      .where(employee_salaries: { effective_to: nil })
                                      .group(
                                        "CASE
                                          WHEN employee_salaries.annual_ctc < 300000 THEN 'Below 3L'
                                          WHEN employee_salaries.annual_ctc < 600000 THEN '3L - 6L'
                                          WHEN employee_salaries.annual_ctc < 1200000 THEN '6L - 12L'
                                          ELSE 'Above 12L'
                                        END"
                                      )
                                      .count
      else
        @salary_ranges = {}
      end

      # Recent hires
      @recent_hires = Employee.active.order(joining_date: :desc).limit(5)

      # Upcoming work anniversaries (next 30 days)
      today = Date.current
      end_date = today + 30.days

      if today.month == end_date.month
        @upcoming_anniversaries = Employee.active.where(
          "EXTRACT(MONTH FROM joining_date) = ? AND EXTRACT(DAY FROM joining_date) BETWEEN ? AND ?",
          today.month, today.day, end_date.day
        )
      else
        @upcoming_anniversaries = Employee.active.where(
          "(EXTRACT(MONTH FROM joining_date) = ? AND EXTRACT(DAY FROM joining_date) >= ?) OR (EXTRACT(MONTH FROM joining_date) = ? AND EXTRACT(DAY FROM joining_date) <= ?)",
          today.month, today.day, end_date.month, end_date.day
        )
      end

      @upcoming_anniversaries = @upcoming_anniversaries.order(
        Arel.sql("EXTRACT(MONTH FROM joining_date), EXTRACT(DAY FROM joining_date)")
      ).limit(5)
    end
  end
end
