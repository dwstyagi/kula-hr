module Platform
  class TenantStatsCalculator
    Result = Struct.new(:total_tenants, :active_tenants, :trial_tenants, :suspended_tenants,
                        :signups_this_month, :total_users, keyword_init: true)

    def self.call
      new.call
    end

    def call
      Result.new(
        total_tenants: Tenant.count,
        active_tenants: Tenant.active.count,
        trial_tenants: Tenant.trial.count,
        suspended_tenants: Tenant.suspended.count,
        signups_this_month: Tenant.where(created_at: Time.current.beginning_of_month..).count,
        total_users: User.count
      )
    end
  end
end
