module Admin
  class EmployeesController < BaseController
    before_action :set_employee, only: [ :show, :edit, :update, :destroy, :resend_invite, :toggle_account_status, :assign_salary, :create_salary, :revise_salary, :create_revision ]

    def template
      authorize Employee, :template?
      package = Employees::TemplateGenerator.new.call
      send_data package.to_stream.read,
                filename: "employees_import_template.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "attachment"
    end

    def export
      authorize Employee, :export?

      employees = policy_scope(Employee)
                    .includes(:department, :designation)
                    .order(:employee_code)

      employees = employees.where("lower(first_name || ' ' || last_name) LIKE :q OR lower(employee_code) LIKE :q", q: "%#{params[:q].to_s.downcase.strip}%") if params[:q].present?
      employees = employees.where(department_id: params[:department_id]) if params[:department_id].present?
      employees = employees.where(employment_status: params[:status]) if params[:status].present?

      file = Employees::ExportGenerator.new(employees).file
      filename = "employees_#{ActsAsTenant.current_tenant.subdomain}_#{Date.today.strftime('%d_%m_%Y')}.xlsx"

      stream_download Downloads::TemporaryFile.new(file), filename: filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end

    def index
      @departments = Department.order(:name)

      @employees = policy_scope(Employee)
                     .includes(:department, :designation, :user)
                     .order(employee_code: :desc)

      @employees = @employees.where("lower(first_name || ' ' || last_name) LIKE :q OR lower(employee_code) LIKE :q", q: "%#{params[:q].to_s.downcase.strip}%") if params[:q].present?
      @employees = @employees.where(department_id: params[:department_id]) if params[:department_id].present?
      @employees = @employees.where(employment_status: params[:status]) if params[:status].present?

      @pagy, @employees = pagy(:offset, @employees, limit: 10)
    end

    def show
      authorize @employee
      @current_salary  = @employee.current_salary
      @salary_history  = @employee.employee_salaries.history.includes(:salary_structure)
      @leave_balances  = @employee.leave_balances.current.includes(:leave_type).order("leave_types.name")
    end

    def new
      tenant = ActsAsTenant.current_tenant
      if tenant.at_employee_limit?
        return redirect_to admin_employees_path,
                           alert: "Trial accounts are limited to #{Tenant::TRIAL_EMPLOYEE_LIMIT} employees. Upgrade to add more."
      end
      @employee = Employee.new
      authorize @employee
      load_form_options
    end

    def create
      @employee = Employee.new(employee_params)
      authorize @employee

      tenant = ActsAsTenant.current_tenant
      if tenant.at_employee_limit?
        load_form_options
        flash.now[:alert] = "Trial accounts are limited to #{Tenant::TRIAL_EMPLOYEE_LIMIT} employees. Upgrade to add more."
        return render :new, status: :unprocessable_entity
      end

      existing_user = User.find_by(email: @employee.email.to_s.strip.downcase)
      if existing_user && (error = existing_account_error(existing_user, tenant))
        @employee.errors.add(:email, error)
        load_form_options
        return render :new, status: :unprocessable_content
      end

      invited = false
      ActiveRecord::Base.transaction do
        if existing_user
          # Someone who already signs in to this company (e.g. an HR admin) is
          # linked to the new employee record; their admin role is kept.
          existing_user.add_role(:employee) unless existing_user.has_role?(:employee)
          @employee.user = existing_user
          @employee.save!
        else
          user = User.create!(
            first_name: @employee.first_name,
            last_name: @employee.last_name,
            email: @employee.email,
            password: SecureRandom.hex(20)
          )

          TenantUser.create!(tenant: tenant, user: user)
          user.assign_role(:employee)
          @employee.user = user
          @employee.save!
          user.invite!(current_user)
          invited = true
        end
        Leave::LeaveBalanceAllocator.new(employee: @employee).call
      end

      notice = invited ? "Employee created and invitation sent to #{@employee.email}." :
                         "Employee created and linked to the existing account for #{@employee.email}."
      redirect_to admin_employee_path(@employee), notice: notice
    rescue ActiveRecord::RecordInvalid => e
      # Surface errors raised on the User (e.g. a malformed email) on the form.
      unless e.record.equal?(@employee)
        e.record.errors.each do |err|
          @employee.errors.add(err.attribute == :email ? :email : :base, err.message)
        end
      end
      load_form_options
      render :new, status: :unprocessable_content
    end

    def resend_invite
      authorize @employee

      if @employee.user
        @employee.user.invite!(current_user)
        redirect_to admin_employee_path(@employee), notice: "Invitation resent to #{@employee.email}."
      else
        ActiveRecord::Base.transaction do
          user = User.create!(
            first_name: @employee.first_name,
            last_name: @employee.last_name,
            email: @employee.email,
            password: SecureRandom.hex(20)
          )
          TenantUser.create!(tenant: ActsAsTenant.current_tenant, user: user)
          user.assign_role(:employee)
          @employee.update!(user: user)
          user.invite!(current_user)
        end
        redirect_to admin_employee_path(@employee), notice: "Invitation sent to #{@employee.email}."
      end
    end

    def toggle_account_status
      authorize @employee
      return redirect_to admin_employee_path(@employee), alert: "Employee has no portal account." unless @employee.user

      if @employee.user.account_active?
        @employee.user.update!(account_active: false)
        redirect_to admin_employee_path(@employee), notice: "Portal access deactivated for #{@employee.full_name}."
      else
        @employee.user.update!(account_active: true)
        redirect_to admin_employee_path(@employee), notice: "Portal access reactivated for #{@employee.full_name}."
      end
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

    def assign_salary
      authorize @employee
      @employee_salary = EmployeeSalary.new(effective_from: Date.today)
      @salary_structures = SalaryStructure.active.order(:name)
    end

    def create_salary
      authorize @employee
      @employee_salary = @employee.employee_salaries.build(salary_params.merge(tenant: ActsAsTenant.current_tenant))

      if @employee_salary.save
        redirect_to admin_employee_path(@employee, anchor: "salary"), notice: "Salary assigned successfully."
      else
        @salary_structures = SalaryStructure.active.order(:name)
        render :assign_salary, status: :unprocessable_content
      end
    end

    def revise_salary
      authorize @employee
      @current_salary = @employee.current_salary
      redirect_to assign_salary_admin_employee_path(@employee), alert: "No current salary to revise." and return unless @current_salary

      @employee_salary = EmployeeSalary.new(
        salary_structure_id: @current_salary.salary_structure_id,
        effective_from: Date.today
      )
      @salary_structures = SalaryStructure.active.order(:name)
    end

    def create_revision
      authorize @employee
      @current_salary = @employee.current_salary
      redirect_to admin_employee_path(@employee), alert: "No current salary to revise." and return unless @current_salary

      ActiveRecord::Base.transaction do
        @current_salary.update!(effective_to: salary_params[:effective_from].to_date - 1.day)
        @employee.employee_salaries.create!(salary_params.merge(tenant: ActsAsTenant.current_tenant))
      end

      redirect_to admin_employee_path(@employee, anchor: "salary"), notice: "Salary revised successfully."
    rescue ActiveRecord::RecordInvalid => e
      @employee_salary = EmployeeSalary.new(salary_params)
      @salary_structures = SalaryStructure.active.order(:name)
      flash.now[:alert] = e.record.errors.full_messages.join(", ")
      render :revise_salary, status: :unprocessable_content
    end

    private

    # Why an existing login cannot be linked to a new employee here, or nil.
    def existing_account_error(user, tenant)
      return "is already used by an account in another company" unless user.member_of?(tenant)

      linked = Employee.where(user: user).first
      "is already linked to employee #{linked.full_name} (#{linked.employee_code})" if linked
    end

    def set_employee
      @employee = Employee.find(params[:id])
    end

    def load_form_options
      @departments = Department.order(:name)
      @designations = Designation.order(:name)
      @managers = Employee.where.not(id: @employee.id).order(:first_name)
      @work_locations = WorkLocation.active.order(:name)
    end

    def salary_params
      params.require(:employee_salary).permit(:salary_structure_id, :annual_ctc, :effective_from)
    end

    def employee_params
      params.require(:employee).permit(
        :first_name, :last_name, :email, :phone,
        :date_of_birth, :gender,
        :joining_date, :confirmation_date, :employment_status,
        :department_id, :designation_id, :reporting_manager_id, :work_location_id,
        :bank_name, :bank_account_number, :ifsc_code,
        :pan_number, :aadhaar_number, :uan_number, :esi_number,
        :current_address, :city, :state, :pincode,
        :emergency_contact_first_name, :emergency_contact_last_name,
        :emergency_contact_phone, :emergency_contact_relation,
        :leave_approver
      )
    end
  end
end
