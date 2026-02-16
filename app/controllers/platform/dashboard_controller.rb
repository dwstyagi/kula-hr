module Platform
  class DashboardController < BaseController
    def index
      @stats = ::Platform::TenantStatsCalculator.call
    end
  end
end
