module Leave
  class MonthlyLeaveAccrualJob < ApplicationJob
    queue_as :scheduled

    def perform
      Leave::MonthlyLeaveAccrualService.run_for_all_tenants
    end
  end
end
