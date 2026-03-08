module Platform
  class DashboardController < BaseController
    def index
      @stats = ::Platform::DashboardStatsService.call
    end
  end
end
