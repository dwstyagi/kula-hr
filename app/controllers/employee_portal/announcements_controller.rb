module EmployeePortal
  class AnnouncementsController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      @announcements = Announcement.published.recent_first
      @read_ids = current_employee.announcement_reads.pluck(:announcement_id).to_set
    end

    def show
      @announcement = Announcement.published.find(params[:id])
      @announcement.mark_read_by!(current_employee)
    end
  end
end
