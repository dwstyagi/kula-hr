module EmployeePortal
  class DashboardController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
    end
  end
end
