module EmployeePortal
  class BaseController < ApplicationController
    before_action :authenticate_user!

    layout "employee_portal"
  end
end
