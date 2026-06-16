module Admin
  class WorkLocationsController < BaseController
    before_action :set_work_location, only: [ :edit, :update, :destroy ]

    def index
      @work_locations = policy_scope(WorkLocation).order(:name)
      authorize WorkLocation
    end

    def new
      @work_location = WorkLocation.new
      authorize @work_location
    end

    def create
      @work_location = WorkLocation.new(work_location_params)
      authorize @work_location

      if @work_location.save
        redirect_to admin_work_locations_path, notice: "Work location created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @work_location
    end

    def update
      authorize @work_location

      if @work_location.update(work_location_params)
        redirect_to admin_work_locations_path, notice: "Work location updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @work_location
      @work_location.destroy!
      redirect_to admin_work_locations_path, notice: "Work location deleted."
    end

    private

    def set_work_location
      @work_location = WorkLocation.find(params[:id])
    end

    def work_location_params
      params.require(:work_location).permit(:name, :state, :is_active)
    end
  end
end
