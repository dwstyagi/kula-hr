module Admin
  class LeaveBalancesController < BaseController
    def index
      balances = policy_scope(LeaveBalance).includes(:employee, :leave_type).order(:employee_id, :leave_type_id)
      if params[:employee].present?
        query = "%#{Employee.sanitize_sql_like(params[:employee].strip)}%"
        balances = balances.joins(:employee).where("employees.employee_code ILIKE :q OR CONCAT(employees.first_name, ' ', employees.last_name) ILIKE :q", q: query)
      end
      balances = balances.where(financial_year: params[:financial_year].presence || FinancialYear.label)
      @pagy, @leave_balances = pagy(:offset, balances, limit: 30)
    end

    def show
      @balance = policy_scope(LeaveBalance).find(params[:id])
      authorize @balance
      @pagy, @entries = pagy(:offset, @balance.leave_balance_entries.includes(:actor).order(id: :desc), limit: 30)
      @adjustment_reference = SecureRandom.uuid
    end

    def adjust
      @balance = policy_scope(LeaveBalance).find(params[:id])
      authorize @balance
      Leave::BalanceAdjustment.call(balance: @balance, days: params[:days], reason: params[:reason],
        actor: current_user, reference: params[:reference])
      redirect_to admin_leave_balance_path(@balance), notice: "Balance adjustment recorded."
    rescue Leave::BalanceAdjustment::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_leave_balance_path(@balance), alert: e.message
    end
  end
end
