module Admin
  class HolidaysController < BaseController
    PER_PAGE_OPTIONS = [ 10, 25, 50 ].freeze

    before_action :set_holiday, only: [ :edit, :update, :destroy, :toggle_active ]

    def index
      holidays = policy_scope(Holiday).includes(:work_location).order(date: :desc)

      @per_page = params[:per_page].to_i
      @per_page = PER_PAGE_OPTIONS.first unless PER_PAGE_OPTIONS.include?(@per_page)
      @pagy, @holidays = pagy(:offset, holidays, limit: @per_page)
    end

    def new
      @holiday = Holiday.new
      authorize @holiday
    end

    def create
      @holiday = Holiday.new(holiday_params)
      authorize @holiday

      if @holiday.save
        redirect_to admin_holidays_path, notice: "Holiday created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @holiday
    end

    def update
      authorize @holiday

      if @holiday.update(holiday_params)
        redirect_to admin_holidays_path, notice: "Holiday updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @holiday
      @holiday.destroy!
      redirect_to admin_holidays_path, notice: "Holiday deleted."
    end

    def toggle_active
      authorize @holiday, :update?
      @holiday.update!(is_active: !@holiday.is_active?)
      redirect_to admin_holidays_path,
        notice: "#{@holiday.name} #{@holiday.is_active? ? 'activated' : 'deactivated'}."
    end

    # POST /admin/holidays/add_standard_presets?year=2026
    # Bulk-creates the standard Indian gazetted holidays for a year as
    # company-wide holidays, skipping any date that already has one.
    def add_standard_presets
      authorize Holiday, :create?

      year = params[:year].presence&.to_i || Date.today.year
      candidates = Holidays::StandardPresets.for_year(year)
      existing_dates = Holiday.company_wide.where(date: candidates.map { |c| c[:date] }).pluck(:date).to_set

      created = candidates.reject { |c| existing_dates.include?(c[:date]) }
      created.each { |c| Holiday.create!(name: c[:name], date: c[:date], is_active: true) }

      if created.any?
        redirect_to admin_holidays_path, notice: "Added #{created.size} standard holiday#{'s' unless created.size == 1} for #{year}."
      else
        redirect_to admin_holidays_path, notice: "Standard holidays for #{year} are already on the calendar."
      end
    end

    private

    def set_holiday
      @holiday = Holiday.find(params[:id])
    end

    def holiday_params
      params.require(:holiday).permit(:name, :date, :is_active, :work_location_id)
    end
  end
end
