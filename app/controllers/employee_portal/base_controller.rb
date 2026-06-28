module EmployeePortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_employee!

    layout "employee_portal"

    private

    def current_employee
      @current_employee ||= Employee.find_by(user: current_user)
    end
    helper_method :current_employee

    # The portal is only for users backed by an Employee record. Without this,
    # any authenticated User (e.g. an HR/super admin, who has no Employee row)
    # could load portal pages — rendering empty at best, 500-ing on the
    # controllers that call current_employee.<x> without a nil-guard at worst.
    def require_employee!
      return if current_employee

      if current_user.has_role?(:super_admin) || current_user.has_role?(:hr_admin)
        redirect_to admin_root_path,
                    alert: "Your account isn't linked to an employee profile. Use the admin panel."
      else
        sign_out(current_user)
        redirect_to new_user_session_path,
                    alert: "No employee profile is linked to this account."
      end
    end
  end
end
