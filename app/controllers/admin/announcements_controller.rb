module Admin
  class AnnouncementsController < BaseController
    before_action :set_announcement, only: [ :show, :edit, :update, :destroy, :publish ]

    def index
      @announcements = policy_scope(Announcement).recent_first
      @read_counts   = AnnouncementRead.group(:announcement_id).count
      @active_count  = Employee.active.count
    end

    def show
      authorize @announcement
      @read_count  = @announcement.announcement_reads.count
      @total_count = Employee.active.count
    end

    def new
      @announcement = Announcement.new
      authorize @announcement
    end

    def create
      @announcement = Announcement.new(announcement_params)
      @announcement.author = current_user
      authorize @announcement

      if @announcement.save
        redirect_to admin_announcements_path, notice: "Announcement created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @announcement
    end

    def update
      authorize @announcement

      if @announcement.update(announcement_params)
        if @announcement.published? && params[:notify_readers] == "1"
          @announcement.notify_readers_of_update!
          redirect_to admin_announcements_path, notice: "Announcement updated. Employees who already read it will see it as unread again."
        else
          redirect_to admin_announcements_path, notice: "Announcement updated."
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @announcement
      @announcement.destroy!
      redirect_to admin_announcements_path, notice: "Announcement deleted."
    end

    def publish
      authorize @announcement, :publish?
      @announcement.publish!
      redirect_to admin_announcements_path, notice: "Announcement published."
    end

    private

    def set_announcement
      @announcement = Announcement.find(params[:id])
    end

    def announcement_params
      params.require(:announcement).permit(:title, :body)
    end
  end
end
