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
      Rails.cache.fetch("platform/dashboard_stats", expires_in: 5.minutes) { compute }
    end

    private

    def compute
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
        top_tenants_by_employees: top_tenants,
        tenant_size_distribution: tenant_size_distribution,

        # Reliability
        failed_payroll_runs_count: PayrollRun.where(status: "rejected", updated_at: 30.days.ago..).count,
        recent_failed_runs: recent_failed_runs,

        # Activity
        recent_tenants: recent_tenants,
        recent_payroll_activity: recent_payroll_activity,

        # Risk
        churn_risk_tenants: churn_risk_tenants,
        inactive_tenants: inactive_tenants
      )
    end

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

    def top_tenants
      counts = Employee.group(:tenant_id).order(Arel.sql("COUNT(*) DESC"), :tenant_id).limit(5).count
      tenants = Tenant.where(id: counts.keys).index_by(&:id)
      counts.filter_map do |id, count|
        tenant = tenants[id]
        { name: tenant.name, subdomain: tenant.subdomain, employee_count: count, status: tenant.status } if tenant
      end
    end

    def tenant_size_distribution
      counts_sql = Employee.select("tenant_id, COUNT(*) AS employee_count").group(:tenant_id).to_sql
      buckets = { "1-10" => 0, "11-50" => 0, "51-100" => 0, "100+" => 0 }
      sql = "SELECT CASE WHEN employee_count <= 10 THEN '1-10' WHEN employee_count <= 50 THEN '11-50' WHEN employee_count <= 100 THEN '51-100' ELSE '100+' END AS bucket, COUNT(*) AS count FROM (#{counts_sql}) counts GROUP BY bucket"
      Employee.connection.select_all(sql).each { |row| buckets[row["bucket"]] = row["count"].to_i }
      buckets
    end

    def recent_tenants
      tenants = Tenant.order(created_at: :desc).limit(5).to_a
      counts = Employee.where(tenant_id: tenants.map(&:id)).group(:tenant_id).count
      tenants.map { |t| { id: t.id, name: t.name, subdomain: t.subdomain, status: t.status, created_at: t.created_at, employee_count: counts[t.id] || 0 } }
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
      recent = PayrollRun.where(created_at: 2.months.ago..).select(:tenant_id)
      at_risk_ids = Tenant.where(status: %w[active trial]).where.not(id: recent).select(:id)
      tenants = Tenant.where(id: at_risk_ids).order(:name).limit(5).to_a
      last_runs = PayrollRun.where(tenant_id: tenants.map(&:id))
                             .select("DISTINCT ON (tenant_id) *")
                             .order(:tenant_id, year: :desc, month: :desc)
                             .index_by(&:tenant_id)
      tenants.map do |t|
        {
          name: t.name, subdomain: t.subdomain, status: t.status,
          last_payroll: last_runs[t.id]&.period_label || "Never"
        }
      end
    end

    def inactive_tenants
      inactive_ids = Tenant.where(status: %w[active trial])
        .where.not(id: PayrollRun.where(created_at: 60.days.ago..).select(:tenant_id))
        .where.not(id: Employee.where(created_at: 60.days.ago..).select(:tenant_id)).select(:id)
      Tenant.where(id: inactive_ids).order(:name).limit(5).pluck(:name, :subdomain)
            .map { |name, subdomain| { name: name, subdomain: subdomain } }
    end
  end
end
