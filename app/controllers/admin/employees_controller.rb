module Admin
  class EmployeesController < BaseController
    before_action :set_employee, only: [ :show, :edit, :update, :destroy ]

    def index
      @employees = policy_scope(Employee)
                     .includes(:department, :designation)
                     .order(created_at: :desc)
      @pagy, @employees = pagy(:offset, @employees, limit: 25)
    end

    def show
      authorize @employee
    end

    def new
      @employee = Employee.new
      authorize @employee
      load_form_options
    end

    def create
      @employee = Employee.new(employee_params)
      authorize @employee

      ActiveRecord::Base.transaction do
        user = User.create!(
          first_name: @employee.first_name,
          last_name: @employee.last_name,
          email: @employee.email,
          password: SecureRandom.hex(8)
        )
        TenantUser.create!(tenant: ActsAsTenant.current_tenant, user: user)
        user.assign_role(:employee)
        @employee.user = user
        @employee.save!
      end

      redirect_to admin_employee_path(@employee), notice: "Employee created successfully."
    rescue ActiveRecord::RecordInvalid
      load_form_options
      render :new, status: :unprocessable_content
    end

    def edit
      authorize @employee
      load_form_options
    end

    def update
      authorize @employee

      if @employee.update(employee_params)
        redirect_to admin_employee_path(@employee), notice: "Employee updated successfully."
      else
        load_form_options
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @employee
      @employee.destroy!
      redirect_to admin_employees_path, notice: "Employee deleted successfully."
    end

    private

    def set_employee
      @employee = Employee.find(params[:id])
    end

    def load_form_options
      @departments = Department.order(:name)
      @designations = Designation.order(:name)
      @managers = Employee.where.not(id: @employee.id).order(:first_name)
    end

    def employee_params
      params.require(:employee).permit(
        :first_name, :last_name, :email, :phone,
        :date_of_birth, :gender,
        :joining_date, :confirmation_date, :employment_status,
        :department_id, :designation_id, :reporting_manager_id,
        :bank_name, :bank_account_number, :ifsc_code,
        :pan_number, :aadhaar_number, :uan_number, :esi_number,
        :current_address, :city, :state, :pincode,
        :emergency_contact_name, :emergency_contact_phone, :emergency_contact_relation
      )
    end
  end
end
