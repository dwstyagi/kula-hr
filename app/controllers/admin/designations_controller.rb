module Admin
  class DesignationsController < BaseController
    before_action :set_designation, only: [ :edit, :update, :destroy ]

    def index
      @designations = policy_scope(Designation).order(:name)
    end

    def new
      @designation = Designation.new
      authorize @designation
    end

    def create
      @designation = Designation.new(designation_params)
      authorize @designation

      if @designation.save
        redirect_to admin_designations_path, notice: "Designation created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @designation
    end

    def update
      authorize @designation

      if @designation.update(designation_params)
        redirect_to admin_designations_path, notice: "Designation updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @designation
      @designation.destroy!
      redirect_to admin_designations_path, notice: "Designation deleted successfully."
    end

    private

    def set_designation
      @designation = Designation.find(params[:id])
    end

    def designation_params
      params.require(:designation).permit(:name)
    end
  end
end
