module Admin
  class LeaveTypesController < BaseController
    before_action :set_leave_type, only: [ :edit, :update, :destroy, :toggle_active ]

    def index
      @leave_types = policy_scope(LeaveType).order(:name)
    end

    def new
      @leave_type = LeaveType.new
      authorize @leave_type
    end

    def create
      @leave_type = LeaveType.new(leave_type_params)
      authorize @leave_type

      if @leave_type.save
        redirect_to admin_leave_types_path, notice: "Leave type created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @leave_type
    end

    def update
      authorize @leave_type

      if @leave_type.update(leave_type_params)
        redirect_to admin_leave_types_path, notice: "Leave type updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @leave_type

      if @leave_type.leave_requests.exists?
        redirect_to admin_leave_types_path, alert: "Cannot delete a leave type that has existing requests."
      else
        @leave_type.destroy!
        redirect_to admin_leave_types_path, notice: "Leave type deleted."
      end
    end

    def toggle_active
      authorize @leave_type, :update?
      @leave_type.update!(is_active: !@leave_type.is_active?)
      redirect_to admin_leave_types_path,
        notice: "#{@leave_type.name} #{@leave_type.is_active? ? 'activated' : 'deactivated'}."
    end

    private

    def set_leave_type
      @leave_type = LeaveType.find(params[:id])
    end

    def leave_type_params
      params.require(:leave_type).permit(:name, :code, :annual_quota, :carry_forward,
                                         :max_carry_forward, :is_paid, :is_active)
    end
  end
end
