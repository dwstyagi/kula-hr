module Admin
  class CompanyProfilesController < BaseController
    before_action :set_tenant

    def show
      authorize @tenant, policy_class: TenantPolicy
    end

    def edit
      authorize @tenant, policy_class: TenantPolicy
    end

    def update
      authorize @tenant, policy_class: TenantPolicy

      if @tenant.update(company_profile_params)
        redirect_to admin_company_profile_path, notice: "Company profile updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_tenant
      @tenant = current_tenant
    end

    def company_profile_params
      params.require(:tenant).permit(
        :name, :gstin, :pan, :tan,
        :pf_establishment_code, :esi_code,
        :address, :city, :state, :pincode
      )
    end
  end
end
