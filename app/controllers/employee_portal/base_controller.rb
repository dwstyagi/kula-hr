module EmployeePortal
  class BaseController < ApplicationController
    before_action :authenticate_user!

    layout "employee_portal"

    private

    def current_employee
      @current_employee ||= Employee.find_by(user: current_user)
    end
    helper_method :current_employee
  end
end
