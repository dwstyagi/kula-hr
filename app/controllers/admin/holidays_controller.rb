module Admin
  class HolidaysController < BaseController
    before_action :set_holiday, only: [ :edit, :update, :destroy, :toggle_active ]

    def index
      @holidays = policy_scope(Holiday).includes(:work_location).order(:date)
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

    private

    def set_holiday
      @holiday = Holiday.find(params[:id])
    end

    def holiday_params
      params.require(:holiday).permit(:name, :date, :is_active, :work_location_id)
    end
  end
end
