module Admin
  class AttendanceSummariesController < BaseController
    before_action :set_month_year
    before_action :set_summary, only: [:show, :edit, :update]

    def index
      authorize AttendanceSummary, :index?
      @summaries = policy_scope(AttendanceSummary)
        .for_month(@month, @year)
        .includes(employee: [:department, :designation])
        .order("employees.last_name, employees.first_name")

      @all_locked    = @summaries.any? && @summaries.all?(&:locked?)
      @any_generated = @summaries.any?
    end

    # Returns read-only row partial (used by Cancel link in edit form)
    def show
      authorize @summary
      render partial: "summary_row", locals: { summary: @summary }
    end

    # Returns editable row form partial
    def edit
      authorize @summary
      render partial: "edit_row", locals: { summary: @summary }
    end

    def update
      authorize @summary

      if @summary.update(summary_params)
        render partial: "summary_row", locals: { summary: @summary }
      else
        render partial: "edit_row", locals: { summary: @summary },
               status: :unprocessable_content
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
      today   = Date.today
      @month  = (params[:month] || today.month).to_i
      @year   = (params[:year]  || today.year).to_i
    end

    def set_summary
      @summary = policy_scope(AttendanceSummary).find(params[:id])
    end

    def summary_params
      params.require(:attendance_summary).permit(:days_present, :half_days)
    end
  end
end
