module Admin
  class DepartmentsController < BaseController
    before_action :set_department, only: [ :edit, :update, :destroy ]

    def index
      @pagy, @departments = pagy(:offset, policy_scope(Department).order(:name), limit: 10)
    end

    def new
      @department = Department.new
      authorize @department
    end

    def create
      @department = Department.new(department_params)
      authorize @department

      if @department.save
        redirect_to admin_departments_path, notice: "Department created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @department
    end

    def update
      authorize @department

      if @department.update(department_params)
        redirect_to admin_departments_path, notice: "Department updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @department
      @department.destroy!
      redirect_to admin_departments_path, notice: "Department deleted successfully."
    end

    private

    def set_department
      @department = Department.find(params[:id])
    end

    def department_params
      params.require(:department).permit(:name)
    end
  end
end
