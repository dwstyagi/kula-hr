class EmployeeRegistrationsController < ApplicationController
  layout :choose_layout

  skip_before_action :authenticate_user!, raise: false
  skip_after_action  :verify_authorized,  raise: false

  before_action :load_and_validate_token
  before_action :load_form_data, only: [ :new, :create ]

  def new
    @employee = Employee.new
  end

  def create
    # Honeypot: bots fill the hidden :website field, humans don't
    if params[:website].present?
      redirect_to employee_registration_sent_path(params[:token]) and return
    end

    tenant = @tenant

    if tenant.at_employee_limit?
      @employee = Employee.new(employee_params)
      flash.now[:alert] = "This company has reached its employee limit. Please contact your HR admin."
      return render :new, status: :unprocessable_content
    end

    ActsAsTenant.with_tenant(tenant) do
      @employee = Employee.new(employee_params)

      if User.exists?(email: @employee.email.to_s.strip.downcase)
        @employee.errors.add(:email, "is already registered. Please contact your HR admin.")
        load_form_data
        return render :new, status: :unprocessable_content
      end

      ActiveRecord::Base.transaction do
        @employee.save!

        user = User.create!(
          first_name: @employee.first_name,
          last_name:  @employee.last_name,
          email:      @employee.email,
          password:   SecureRandom.hex(20)
        )

        TenantUser.create!(tenant: tenant, user: user)
        user.assign_role(:employee)
        @employee.update!(user: user)
        user.invite!

        Leave::LeaveBalanceAllocator.new(employee: @employee).call
      end
    end

    redirect_to employee_registration_sent_path(params[:token])
  rescue ActiveRecord::RecordInvalid
    load_form_data
    render :new, status: :unprocessable_content
  end

  def sent
  end

  private

  def load_and_validate_token
    @tenant = Tenant.find_by(
      subdomain:   request.subdomain,
      invite_token: params[:token]
    )

    unless @tenant&.invite_token_valid?
      render "employee_registrations/invalid_token", status: :not_found
    end
  end

  def load_form_data
    ActsAsTenant.with_tenant(@tenant) do
      @departments  = Department.order(:name)
      @designations = Designation.order(:name)
    end
  end

  def choose_layout
    action_name == "new" || action_name == "create" ? "application" : "auth"
  end

  def employee_params
    params.require(:employee).permit(
      :first_name, :last_name, :email, :phone,
      :date_of_birth, :gender,
      :joining_date, :confirmation_date, :employment_status,
      :department_id, :designation_id,
      :bank_name, :bank_account_number, :ifsc_code,
      :pan_number, :aadhaar_number, :uan_number, :esi_number,
      :current_address, :city, :state, :pincode,
      :emergency_contact_first_name, :emergency_contact_last_name,
      :emergency_contact_phone, :emergency_contact_relation
    )
  end
end
