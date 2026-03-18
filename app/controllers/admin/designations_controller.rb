module Admin
  class DesignationsController < BaseController
    before_action :set_designation, only: [ :edit, :update, :destroy ]

    def index
      @pagy, @designations = pagy(:offset, policy_scope(Designation).order(:name), limit: 10)
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

    def bulk_import
      authorize Designation, :create?

      unless params[:file].present?
        return redirect_to admin_designations_path, alert: "Please select a CSV file."
      end

      names = parse_names(params[:file].read)

      if names.empty?
        return redirect_to admin_designations_path, alert: "No valid names found in the file."
      end

      tenant    = ActsAsTenant.current_tenant
      existing  = Designation.where("lower(name) IN (?)", names.map(&:downcase)).pluck(:name).map(&:downcase).to_set
      to_create = names.reject { |n| existing.include?(n.downcase) }

      Designation.insert_all(to_create.map { |n| { name: n, tenant_id: tenant.id, created_at: Time.current, updated_at: Time.current } }) if to_create.any?

      skipped = names.size - to_create.size
      notice  = "#{to_create.size} #{'designation'.pluralize(to_create.size)} imported."
      notice += " #{skipped} skipped (already exist)." if skipped > 0

      redirect_to admin_designations_path, notice: notice
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
