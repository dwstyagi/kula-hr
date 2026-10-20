module EmployeePortal
  class LeaveBalancesController < BaseController
    def show
      @balance = policy_scope(LeaveBalance).joins(:employee).where(employees: { user_id: current_user.id }).find(params[:id])
      authorize @balance
      @pagy, @entries = pagy(:offset, @balance.leave_balance_entries.includes(:actor).order(id: :desc), limit: 30)
    end
  end
end
