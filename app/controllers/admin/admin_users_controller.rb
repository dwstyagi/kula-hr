module Admin
  class AdminUsersController < BaseController
    before_action :set_admin_user, only: [ :destroy ]
    skip_after_action :verify_policy_scoped, only: [ :index ]

    def index
      authorize :admin_user, :index?, policy_class: AdminUserPolicy
      @admin_users = ActsAsTenant.current_tenant.users
                       .joins("JOIN users_roles ON users_roles.user_id = users.id")
                       .joins("JOIN roles ON roles.id = users_roles.role_id")
                       .where(roles: { name: %w[super_admin hr_admin] })
                       .distinct
                       .order(:first_name, :last_name)
    end

    def new
      authorize :admin_user, :new?, policy_class: AdminUserPolicy
      @user = User.new
    end

    def create
      authorize :admin_user, :create?, policy_class: AdminUserPolicy

      email = params.dig(:user, :email).to_s.strip.downcase

      if ActsAsTenant.current_tenant.users.exists?(email: email)
        return redirect_to admin_admin_users_path, alert: "#{email} is already a member of this organisation."
      end

      ActiveRecord::Base.transaction do
        user = User.new(
          first_name: params.dig(:user, :first_name),
          last_name:  params.dig(:user, :last_name),
          email:      email,
          password:   SecureRandom.hex(20)
        )
        user.save!
        TenantUser.create!(tenant: ActsAsTenant.current_tenant, user: user)
        user.add_role(:hr_admin)
        user.invite!(current_user)
      end

      redirect_to admin_admin_users_path, notice: "Invitation sent to #{email}."
    rescue ActiveRecord::RecordInvalid => e
      @user = User.new(first_name: params.dig(:user, :first_name), last_name: params.dig(:user, :last_name), email: params.dig(:user, :email))
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end

    def destroy
      authorize @admin_user, :destroy?, policy_class: AdminUserPolicy

      if @admin_user.has_role?(:super_admin)
        return redirect_to admin_admin_users_path, alert: "Cannot remove a Super Admin."
      end

      if @admin_user == current_user
        return redirect_to admin_admin_users_path, alert: "You cannot remove your own access."
      end

      @admin_user.remove_role(:hr_admin)
      TenantUser.find_by(tenant: ActsAsTenant.current_tenant, user: @admin_user)&.destroy!

      redirect_to admin_admin_users_path, notice: "#{@admin_user.full_name}'s access has been revoked."
    end

    private

    def set_admin_user
      @admin_user = User.find(params[:id])
    end
  end
end
