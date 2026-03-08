module Platform
  class DashboardStatsService
    Result = Struct.new(
      # Growth
      :total_tenants, :active_tenants, :trial_tenants, :suspended_tenants,
      :signups_this_month, :total_users, :total_employees, :avg_company_size,
      :tenant_growth,
      # Usage
      :payroll_runs_this_month, :total_payroll_processed,
      :tenants_ran_payroll_this_month,
      # Health
      :status_distribution, :top_tenants_by_employees, :tenant_size_distribution,
      # Reliability
      :failed_payroll_runs_count, :recent_failed_runs,
      # Activity
      :recent_tenants, :recent_payroll_activity,
      # Risk
      :churn_risk_tenants, :inactive_tenants,
      keyword_init: true
    )

    def self.call
      new.call
    end

    def call
      employee_counts = Employee.group(:tenant_id).count
      tenant_map = Tenant.where(id: employee_counts.keys).index_by(&:id)

      Result.new(
        # Growth
        total_tenants: Tenant.count,
        active_tenants: Tenant.active.count,
        trial_tenants: Tenant.trial.count,
        suspended_tenants: Tenant.suspended.count,
        signups_this_month: Tenant.where(created_at: Time.current.beginning_of_month..).count,
        total_users: User.count,
        total_employees: Employee.count,
        avg_company_size: avg_company_size,
        tenant_growth: tenant_growth,

        # Usage
        payroll_runs_this_month: PayrollRun.where(created_at: Time.current.beginning_of_month..).count,
        total_payroll_processed: PayrollRun.where(status: %w[approved paid]).sum(:total_net_pay),
        tenants_ran_payroll_this_month: tenants_ran_payroll_this_month,

        # Health
        status_distribution: Tenant.group(:status).count.transform_keys(&:titleize),
        top_tenants_by_employees: top_tenants(employee_counts, tenant_map),
        tenant_size_distribution: tenant_size_distribution(employee_counts),

        # Reliability
        failed_payroll_runs_count: PayrollRun.where(status: "rejected", updated_at: 30.days.ago..).count,
        recent_failed_runs: recent_failed_runs,

        # Activity
        recent_tenants: recent_tenants(employee_counts),
        recent_payroll_activity: recent_payroll_activity,

        # Risk
        churn_risk_tenants: churn_risk_tenants,
        inactive_tenants: inactive_tenants
      )
    end

    private

    def avg_company_size
      tenant_count = Tenant.count
      return 0 if tenant_count.zero?

      (Employee.count.to_f / tenant_count).round(1)
    end

    def tenant_growth
      Tenant.where(created_at: 6.months.ago.beginning_of_month..)
            .group_by_month(:created_at, format: "%b %Y")
            .count
    end

    def tenants_ran_payroll_this_month
      today = Date.current
      PayrollRun.where(month: today.month, year: today.year)
               .distinct
               .count(:tenant_id)
    end

    def top_tenants(employee_counts, tenant_map)
      employee_counts
        .sort_by { |_, count| -count }
        .first(5)
        .map do |tenant_id, count|
          tenant = tenant_map[tenant_id]
          next unless tenant

          { name: tenant.name, subdomain: tenant.subdomain, employee_count: count, status: tenant.status }
        end.compact
    end

    def tenant_size_distribution(employee_counts)
      buckets = { "1-10" => 0, "11-50" => 0, "51-100" => 0, "100+" => 0 }
      employee_counts.each_value do |count|
        case count
        when 1..10 then buckets["1-10"] += 1
        when 11..50 then buckets["11-50"] += 1
        when 51..100 then buckets["51-100"] += 1
        else buckets["100+"] += 1
        end
      end
      buckets
    end

    def recent_tenants(employee_counts)
      Tenant.order(created_at: :desc).limit(5).map do |t|
        {
          id: t.id, name: t.name, subdomain: t.subdomain,
          status: t.status, created_at: t.created_at,
          employee_count: employee_counts[t.id] || 0
        }
      end
    end

    def recent_failed_runs
      PayrollRun.where(status: "rejected")
               .order(updated_at: :desc)
               .limit(5)
               .includes(:tenant)
               .map do |run|
                 {
                   tenant_name: run.tenant.name,
                   period: run.period_label,
                   rejection_reason: run.rejection_reason,
                   updated_at: run.updated_at
                 }
               end
    end

    def recent_payroll_activity
      PayrollRun.order(updated_at: :desc)
               .limit(5)
               .includes(:tenant, :initiated_by)
               .map do |run|
                 {
                   tenant_name: run.tenant.name,
                   period: run.period_label,
                   status: run.status,
                   initiator: run.initiated_by&.full_name || "System",
                   updated_at: run.updated_at
                 }
               end
    end

    def churn_risk_tenants
      active_tenant_ids = Tenant.where(status: %w[active trial]).pluck(:id)
      return [] if active_tenant_ids.empty?

      recent_payroll_tenant_ids = PayrollRun
        .where(tenant_id: active_tenant_ids)
        .where(created_at: 2.months.ago..)
        .distinct
        .pluck(:tenant_id)

      at_risk_ids = active_tenant_ids - recent_payroll_tenant_ids
      Tenant.where(id: at_risk_ids).order(:name).limit(5).map do |t|
        last_run = PayrollRun.where(tenant_id: t.id).order(year: :desc, month: :desc).first
        {
          name: t.name, subdomain: t.subdomain, status: t.status,
          last_payroll: last_run&.period_label || "Never"
        }
      end
    end

    def inactive_tenants
      active_ids = Tenant.where(status: %w[active trial]).pluck(:id)
      return [] if active_ids.empty?

      recently_active_ids = Set.new
      recently_active_ids.merge(
        PayrollRun.where(tenant_id: active_ids, created_at: 60.days.ago..).distinct.pluck(:tenant_id)
      )
      recently_active_ids.merge(
        Employee.where(tenant_id: active_ids, created_at: 60.days.ago..).distinct.pluck(:tenant_id)
      )

      inactive_ids = active_ids - recently_active_ids.to_a
      Tenant.where(id: inactive_ids).order(:name).limit(5).pluck(:name, :subdomain)
            .map { |name, subdomain| { name: name, subdomain: subdomain } }
    end
  end
end
