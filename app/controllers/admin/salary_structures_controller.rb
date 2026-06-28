module Admin
  class SalaryStructuresController < BaseController
    before_action :set_salary_structure, only: [ :show, :edit, :update, :destroy, :toggle_active, :add_component, :remove_component ]

    def index
      @salary_structures = policy_scope(SalaryStructure)
                             .includes(salary_structure_components: :salary_component)
                             .order(:name)
    end

    def show
      authorize @salary_structure
      @components = @salary_structure.salary_structure_components
                      .includes(:salary_component)
                      .joins(:salary_component)
                      .order("salary_components.component_type, salary_components.sort_order")
      # Only earnings belong in a structure. PF/ESI/PT/TDS are statutory and are
      # computed automatically at payroll time — adding them here is a no-op, so
      # we don't offer them. See docs/MANUAL_TEST_TRACKER.md ISSUE-2.
      @available_components = SalaryComponent.active.earnings
                                .where.not(id: @salary_structure.salary_component_ids)
                                .order(:sort_order, :name)
    end

    def new
      @salary_structure = SalaryStructure.new
      authorize @salary_structure
    end

    def create
      @salary_structure = SalaryStructure.new(salary_structure_params)
      authorize @salary_structure

      if @salary_structure.save
        redirect_to admin_salary_structure_path(@salary_structure), notice: "Salary structure created. Now add components below."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @salary_structure
    end

    def update
      authorize @salary_structure

      if @salary_structure.update(salary_structure_params)
        redirect_to admin_salary_structure_path(@salary_structure), notice: "Salary structure updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @salary_structure
      @salary_structure.destroy!
      redirect_to admin_salary_structures_path, notice: "Salary structure deleted."
    end

    def toggle_active
      authorize @salary_structure, :update?
      @salary_structure.update!(active: !@salary_structure.active?)
      redirect_to admin_salary_structures_path,
        notice: "#{@salary_structure.name} #{@salary_structure.active? ? 'activated' : 'deactivated'}."
    end

    def add_component
      authorize @salary_structure

      ssc = @salary_structure.salary_structure_components.build(component_params)

      # Defense in depth: reject non-earning components even if the request is
      # crafted by hand — statutory deductions are never part of a structure.
      unless ssc.salary_component&.earning?
        return redirect_to admin_salary_structure_path(@salary_structure),
          alert: "Only earning components can be added. PF, ESI, Professional Tax and TDS are calculated automatically."
      end

      if ssc.save
        redirect_to admin_salary_structure_path(@salary_structure), notice: "#{ssc.salary_component.name} added."
      else
        redirect_to admin_salary_structure_path(@salary_structure), alert: ssc.errors.full_messages.join(", ")
      end
    end

    def remove_component
      authorize @salary_structure

      ssc = @salary_structure.salary_structure_components.find(params[:component_id])
      name = ssc.salary_component.name
      ssc.destroy!
      redirect_to admin_salary_structure_path(@salary_structure), notice: "#{name} removed."
    end

    private

    def set_salary_structure
      @salary_structure = SalaryStructure.find(params[:id])
    end

    def salary_structure_params
      params.require(:salary_structure).permit(:name)
    end

    def component_params
      params.require(:salary_structure_component).permit(:salary_component_id, :value)
    end
  end
end
