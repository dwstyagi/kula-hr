module Admin
  class SalaryComponentsController < BaseController
    before_action :set_salary_component, only: [ :edit, :update, :destroy, :toggle_active ]

    def index
      components = policy_scope(SalaryComponent).order(:sort_order, :name)
      @earnings = components.earnings
      @deductions = components.deductions
      @employer_contributions = components.employer_contributions
    end

    def new
      @salary_component = SalaryComponent.new
      authorize @salary_component
    end

    def create
      @salary_component = SalaryComponent.new(salary_component_params)
      authorize @salary_component

      if @salary_component.save
        redirect_to admin_salary_components_path, notice: "Salary component created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @salary_component
    end

    def update
      authorize @salary_component

      if @salary_component.update(salary_component_params)
        redirect_to admin_salary_components_path, notice: "Salary component updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @salary_component
      @salary_component.destroy!
      redirect_to admin_salary_components_path, notice: "Salary component deleted successfully."
    end

    def toggle_active
      authorize @salary_component, :update?
      @salary_component.update!(active: !@salary_component.active?)
      redirect_to admin_salary_components_path,
        notice: "#{@salary_component.name} #{@salary_component.active? ? 'activated' : 'deactivated'}."
    end

    private

    def set_salary_component
      @salary_component = SalaryComponent.find(params[:id])
    end

    def salary_component_params
      params.require(:salary_component).permit(:name, :component_type, :calculation_type, :taxable, :sort_order)
    end
  end
end
