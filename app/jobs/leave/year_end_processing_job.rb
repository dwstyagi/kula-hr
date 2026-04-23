module Leave
  class YearEndProcessingJob < ApplicationJob
    queue_as :scheduled

    def perform
      Leave::YearEndProcessingService.run_for_all_tenants
    end
  end
end
