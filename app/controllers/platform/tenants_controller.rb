module Platform
  class TenantsController < BaseController
    before_action :set_tenant, only: [ :show, :edit, :update, :toggle_status ]

    def index
      @pagy, @tenants = pagy(:offset, Tenant.order(created_at: :desc), limit: 25)
    end

    def new
      @signup_form = SignupForm.new
    end

    def create
      @signup_form = SignupForm.new(signup_form_params)

      if @signup_form.valid?
        result = Tenants::TenantOnboarder.call(@signup_form)

        if result.success?
          redirect_to platform_admin_tenant_path(result.tenant), notice: "Tenant '#{result.tenant.name}' created successfully."
        else
          flash.now[:alert] = result.error
          render :new, status: :unprocessable_entity
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def edit
    end

    def update
      if @tenant.update(tenant_params)
        redirect_to platform_admin_tenant_path(@tenant), notice: "Tenant updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_status
      new_status = case @tenant.status
      when "trial", "suspended" then "active"
      when "active" then "suspended"
      else @tenant.status
      end

      if @tenant.update(status: new_status)
        redirect_to platform_admin_tenants_path, notice: "#{@tenant.name} is now #{new_status}."
      else
        redirect_to platform_admin_tenants_path, alert: "Failed to update status."
      end
    end

    private

    def set_tenant
      @tenant = Tenant.find(params[:id])
    end

    def signup_form_params
      params.require(:signup_form).permit(
        :company_name, :subdomain, :state,
        :first_name, :last_name, :email,
        :password, :password_confirmation
      )
    end

    def tenant_params
      params.require(:tenant).permit(:name, :status, :gstin, :pan, :tan,
                                     :pf_establishment_code, :esi_code,
                                     :address, :city, :state, :pincode)
    end
  end
end
