module EmployeePortal
  class ProfilesController < BaseController
    before_action :ensure_employee

    def show
      authorize current_employee, :show?
    end

    def edit
      authorize current_employee, :update_profile?
    end

    def update
      authorize current_employee, :update_profile?

      if current_employee.update(profile_params)
        redirect_to employee_portal_profile_path, notice: "Profile updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def ensure_employee
      redirect_to employee_portal_root_path, alert: "No employee profile found." unless current_employee
    end

    def profile_params
      params.require(:employee).permit(
        :phone, :date_of_birth, :current_address, :pincode, :city, :state,
        :bank_account_number, :bank_name, :ifsc_code,
        :pan_number, :aadhaar_number,
        :emergency_contact_name, :emergency_contact_phone, :emergency_contact_relation
      )
    end
  end
end
