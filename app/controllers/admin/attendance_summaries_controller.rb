module Admin
  class AttendanceSummariesController < BaseController
    before_action :set_month_year
    before_action :check_month_open, only: [ :index, :generate, :lock_month, :unlock_month,
                                             :download_template, :upload_template ]
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

    # Safety valve for a month locked too early. Super admin only, and refused
    # once payroll has moved past draft for that month — those payslips were
    # calculated from the locked attendance and would silently desync.
    def unlock_month
      authorize AttendanceSummary, :unlock_month?

      if (blocking = PayrollRun.for_month(@month, @year).where.not(status: "draft").first)
        redirect_to admin_attendance_summaries_path(month: @month, year: @year),
          alert: "Can't unlock #{Date::MONTHNAMES[@month]} #{@year} — its payroll run is already #{blocking.status.humanize.downcase}. Reprocess the run back to draft first."
        return
      end

      count = policy_scope(AttendanceSummary)
        .for_month(@month, @year)
        .where(status: :locked)
        .update_all(status: :draft)

      redirect_to admin_attendance_summaries_path(month: @month, year: @year),
        notice: "#{count} attendance #{"record".pluralize(count)} unlocked for #{Date::MONTHNAMES[@month]} #{@year}."
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
      default = Attendance::MonthWindow.latest_open
      @month  = (params[:month] || default.month).to_i.clamp(1, 12)
      @year   = (params[:year]  || default.year).to_i.clamp(2000, 2099)
    end

    def check_month_open
      return if Attendance::MonthWindow.open?(@month, @year)

      latest = Attendance::MonthWindow.latest_open
      redirect_to admin_attendance_summaries_path(month: latest.month, year: latest.year),
        alert: month_closed_message(latest)
    end

    # Two distinct reasons a month can be closed: it is still running (opens in
    # its final week), or it hasn't happened yet.
    def month_closed_message(latest)
      period = "#{Date::MONTHNAMES[@month]} #{@year}"
      showing = "Showing #{latest.strftime("%B %Y")}."

      if Date.new(@year, @month, 1) == Date.current.beginning_of_month
        opens = Attendance::MonthWindow.opens_on
        "Attendance for #{period} opens on #{opens.strftime("%d %b")}, once the month is nearly over. #{showing}"
      else
        "Cannot manage attendance for #{period} — that month hasn't happened yet. #{showing}"
      end
    end

    def set_summary
      @summary = policy_scope(AttendanceSummary).find(params[:id])
    end

    def summary_params
      params.require(:attendance_summary).permit(:days_present, :half_days)
    end
  end
end
