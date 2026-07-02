module Admin
  class AttendanceSummariesController < BaseController
    before_action :set_month_year
    before_action :check_future_month, only: [ :index, :generate, :lock_month, :download_template, :upload_template ]
    before_action :set_summary, only: [ :show, :edit, :update ]

    def index
      authorize AttendanceSummary, :index?
      @summaries = policy_scope(AttendanceSummary)
        .for_month(@month, @year)
        .includes(employee: [ :department, :designation ])
        .order("employees.last_name, employees.first_name")

      @all_locked    = @summaries.any? && @summaries.all?(&:locked?)
      @any_generated = @summaries.any?
    end

    def show
      authorize @summary
      redirect_to admin_attendance_summaries_path(month: @summary.month, year: @summary.year)
    end

    def edit
      authorize @summary
      @summaries = policy_scope(AttendanceSummary)
        .for_month(@summary.month, @summary.year)
        .includes(employee: [ :department, :designation ])
        .order("employees.last_name, employees.first_name")
      @month = @summary.month
      @year = @summary.year
      @all_locked = @summaries.any? && @summaries.all?(&:locked?)
      @any_generated = @summaries.any?
      @editing_summary = @summary
      render :index
    end

    def update
      authorize @summary

      if @summary.update(summary_params)
        redirect_to admin_attendance_summaries_path(month: @summary.month, year: @summary.year),
          notice: "Attendance updated for #{@summary.employee.full_name}."
      else
        @summaries = policy_scope(AttendanceSummary)
          .for_month(@summary.month, @summary.year)
          .includes(employee: [ :department, :designation ])
          .order("employees.last_name, employees.first_name")
        @month = @summary.month
        @year = @summary.year
        @all_locked = @summaries.any? && @summaries.all?(&:locked?)
        @any_generated = @summaries.any?
        @editing_summary = @summary
        render :index, status: :unprocessable_content
      end
    end

    def generate
      authorize AttendanceSummary, :generate?

      Attendance::SummaryGenerator.new(
        month: @month, year: @year, tenant: ActsAsTenant.current_tenant
      ).call

      redirect_to admin_attendance_summaries_path(month: @month, year: @year),
        notice: "Attendance summary generated for #{Date::MONTHNAMES[@month]} #{@year}."
    end

    def lock_month
      authorize AttendanceSummary, :lock_month?

      count = policy_scope(AttendanceSummary)
        .for_month(@month, @year)
        .where(status: :draft)
        .update_all(status: :locked)

      redirect_to admin_attendance_summaries_path(month: @month, year: @year),
        notice: "#{count} attendance #{"record".pluralize(count)} locked for #{Date::MONTHNAMES[@month]} #{@year}."
    end

    def download_template
      authorize AttendanceSummary, :download_template?

      csv_data = Attendance::TemplateGenerator.new(
        month: @month, year: @year, tenant: ActsAsTenant.current_tenant
      ).call

      filename = "attendance_#{@year}_#{@month.to_s.rjust(2, '0')}.csv"
      send_data csv_data, filename: filename, type: "text/csv", disposition: "attachment"
    end

    def upload_template
      authorize AttendanceSummary, :upload_template?

      unless params[:file].present?
        return redirect_to admin_attendance_summaries_path(month: @month, year: @year),
                           alert: "Please select a CSV file to upload."
      end

      result = Attendance::TemplateImporter.new(
        file: params[:file], month: @month, year: @year,
        tenant: ActsAsTenant.current_tenant
      ).call

      if result.success?
        redirect_to admin_attendance_summaries_path(month: @month, year: @year),
          notice: "#{result.imported_count} records updated successfully."
      else
        redirect_to admin_attendance_summaries_path(month: @month, year: @year),
          alert: "Import completed with errors: #{result.errors.first(3).join('; ')}"
      end
    end

    private

    def set_month_year
      default = Date.today.prev_month
      @month  = (params[:month] || default.month).to_i
      @year   = (params[:year]  || default.year).to_i
    end

    def check_future_month
      redirect_to_latest_allowed_month if future_month?
    end

    def future_month?
      Date.new(@year, @month, 1) > Date.today.prev_month.beginning_of_month
    end

    def redirect_to_latest_allowed_month
      latest = Date.today.prev_month
      redirect_to admin_attendance_summaries_path(month: latest.month, year: latest.year),
        alert: "Cannot process attendance for #{Date::MONTHNAMES[@month]} #{@year}. Attendance can only be managed up to the previous month (#{Date::MONTHNAMES[latest.month]} #{latest.year})."
    end

    def set_summary
      @summary = policy_scope(AttendanceSummary).find(params[:id])
    end

    def summary_params
      params.require(:attendance_summary).permit(:days_present, :half_days)
    end
  end
end
