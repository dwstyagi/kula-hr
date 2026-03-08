module Dashboard
  class AdminDashboardService
    Result = Struct.new(
      :current_run, :current_run_status, :current_run_net, :current_run_ctc,
      :current_run_employees, :payroll_trend, :deduction_breakdown, :recent_activity,
      :pending_leave_count, :pending_leave_requests,
      keyword_init: true
    )

    def initialize(tenant:)
      @tenant = tenant
    end

    def call
      current = current_payroll_run
      Result.new(
        current_run: current,
        current_run_status: current&.status&.titleize || "No Payroll Run",
        current_run_net: current&.total_net_pay || 0,
        current_run_ctc: current&.total_employer_cost || 0,
        current_run_employees: current&.processed_employees || 0,
        payroll_trend: payroll_trend,
        deduction_breakdown: deduction_breakdown(current),
        recent_activity: recent_activity,
        pending_leave_count: pending_leaves.count,
        pending_leave_requests: pending_leaves.limit(5)
      )
    end

    private

    def current_payroll_run
      PayrollRun.order(year: :desc, month: :desc).first
    end

    def payroll_trend
      PayrollRun.where(status: %w[approved paid])
                .order(year: :desc, month: :desc)
                .limit(6)
                .reverse
                .map do |run|
                  label = "#{Date::ABBR_MONTHNAMES[run.month]} #{run.year}"
                  {
                    label: label,
                    gross: run.total_gross.to_f.round(0),
                    net: run.total_net_pay.to_f.round(0),
                    ctc: run.total_employer_cost.to_f.round(0)
                  }
                end
    end

    def deduction_breakdown(current_run)
      return {} unless current_run

      PayslipLineItem.joins(:payslip)
                     .where(payslips: { payroll_run_id: current_run.id }, component_type: "deduction")
                     .group(:component_name)
                     .sum(:amount)
                     .transform_values { |v| v.to_f.round(0) }
    end

    def pending_leaves
      LeaveRequest.where(status: :pending)
                  .includes(:employee, :leave_type)
                  .order(created_at: :desc)
    end

    def recent_activity
      PayrollRun.order(updated_at: :desc).limit(5).map do |run|
        {
          period: run.period_label,
          status: run.status,
          updated_at: run.updated_at,
          initiator: run.initiated_by&.full_name
        }
      end
    end
  end
end
