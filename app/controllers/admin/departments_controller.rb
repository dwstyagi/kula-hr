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

    def bulk_import
      authorize Department, :create?

      unless params[:file].present?
        return redirect_to admin_departments_path, alert: "Please select a CSV file."
      end

      names = parse_names(params[:file].read)

      if names.empty?
        return redirect_to admin_departments_path, alert: "No valid names found in the file."
      end

      tenant    = ActsAsTenant.current_tenant
      existing  = Department.where("lower(name) IN (?)", names.map(&:downcase)).pluck(:name).map(&:downcase).to_set
      to_create = names.reject { |n| existing.include?(n.downcase) }

      Department.insert_all(to_create.map { |n| { name: n, tenant_id: tenant.id, created_at: Time.current, updated_at: Time.current } }) if to_create.any?

      skipped = names.size - to_create.size
      notice  = "#{to_create.size} #{'department'.pluralize(to_create.size)} imported."
      notice += " #{skipped} skipped (already exist)." if skipped > 0

      redirect_to admin_departments_path, notice: notice
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

    def parse_names(content)
      content.force_encoding("UTF-8")
             .lines
             .map { |l| l.strip.split(",").first.to_s.strip }
             .reject(&:blank?)
             .reject { |n| n.downcase == "name" }
             .uniq { |n| n.downcase }
    end
  end
end
