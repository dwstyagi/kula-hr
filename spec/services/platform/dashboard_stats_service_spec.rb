require "rails_helper"

RSpec.describe Platform::DashboardStatsService do
  subject(:result) { described_class.call }

  let!(:tenant_active) { create(:tenant, status: "active") }
  let!(:tenant_trial) { create(:tenant, status: "trial") }

  describe "growth metrics" do
    it "returns tenant counts by status" do
      expect(result.total_tenants).to eq(2)
      expect(result.active_tenants).to eq(1)
      expect(result.trial_tenants).to eq(1)
      expect(result.suspended_tenants).to eq(0)
    end

    it "counts signups this month" do
      expect(result.signups_this_month).to eq(2)
    end

    it "counts total users" do
      create_list(:user, 3)
      expect(described_class.call.total_users).to eq(3)
    end

    it "counts total employees across all tenants" do
      ActsAsTenant.with_tenant(tenant_active) { create_list(:employee, 3, tenant: tenant_active) }
      ActsAsTenant.with_tenant(tenant_trial) { create_list(:employee, 2, tenant: tenant_trial) }
      expect(described_class.call.total_employees).to eq(5)
    end

    it "calculates average company size" do
      ActsAsTenant.with_tenant(tenant_active) { create_list(:employee, 4, tenant: tenant_active) }
      expect(described_class.call.avg_company_size).to eq(2.0)
    end

    it "returns tenant growth by month" do
      expect(result.tenant_growth).to be_a(Hash)
    end
  end

  describe "usage metrics" do
    it "counts payroll runs this month" do
      ActsAsTenant.with_tenant(tenant_active) do
        create(:payroll_run, tenant: tenant_active, month: Date.current.month, year: Date.current.year)
      end
      expect(described_class.call.payroll_runs_this_month).to eq(1)
    end

    it "sums total payroll processed" do
      ActsAsTenant.with_tenant(tenant_active) do
        create(:payroll_run, :approved, tenant: tenant_active, total_net_pay: 100_000)
      end
      expect(described_class.call.total_payroll_processed).to eq(100_000)
    end

    it "counts distinct tenants that ran payroll this month" do
      ActsAsTenant.with_tenant(tenant_active) do
        create(:payroll_run, tenant: tenant_active, month: Date.current.month, year: Date.current.year)
      end
      expect(described_class.call.tenants_ran_payroll_this_month).to eq(1)
    end
  end

  describe "health metrics" do
    it "returns status distribution" do
      expect(result.status_distribution).to include("Active" => 1, "Trial" => 1)
    end

    it "returns top tenants by employee count" do
      ActsAsTenant.with_tenant(tenant_active) { create_list(:employee, 5, tenant: tenant_active) }
      ActsAsTenant.with_tenant(tenant_trial) { create_list(:employee, 2, tenant: tenant_trial) }
      top = described_class.call.top_tenants_by_employees
      expect(top.first[:employee_count]).to eq(5)
    end

    it "buckets tenant size distribution" do
      ActsAsTenant.with_tenant(tenant_active) { create_list(:employee, 5, tenant: tenant_active) }
      dist = described_class.call.tenant_size_distribution
      expect(dist["1-10"]).to eq(1)
    end
  end

  describe "reliability metrics" do
    it "counts failed payroll runs in last 30 days" do
      ActsAsTenant.with_tenant(tenant_active) do
        create(:payroll_run, :rejected, tenant: tenant_active)
      end
      expect(described_class.call.failed_payroll_runs_count).to eq(1)
    end

    it "lists recent failed runs with tenant info" do
      ActsAsTenant.with_tenant(tenant_active) do
        create(:payroll_run, :rejected, tenant: tenant_active, rejection_reason: "Bad data")
      end
      runs = described_class.call.recent_failed_runs
      expect(runs.first[:tenant_name]).to eq(tenant_active.name)
      expect(runs.first[:rejection_reason]).to eq("Bad data")
    end
  end

  describe "activity metrics" do
    it "returns recent tenants with employee count" do
      ActsAsTenant.with_tenant(tenant_active) { create_list(:employee, 3, tenant: tenant_active) }
      recent = described_class.call.recent_tenants
      tenant_entry = recent.find { |t| t[:id] == tenant_active.id }
      expect(tenant_entry[:employee_count]).to eq(3)
    end

    it "returns recent payroll activity" do
      ActsAsTenant.with_tenant(tenant_active) do
        create(:payroll_run, tenant: tenant_active)
      end
      activity = described_class.call.recent_payroll_activity
      expect(activity.first[:tenant_name]).to eq(tenant_active.name)
    end
  end

  describe "risk signals" do
    it "identifies churn risk tenants with no recent payroll" do
      # tenant_active has no payroll runs → churn risk
      churn = result.churn_risk_tenants
      names = churn.map { |t| t[:name] }
      expect(names).to include(tenant_active.name)
    end

    it "identifies inactive tenants" do
      inactive = result.inactive_tenants
      names = inactive.map { |t| t[:name] }
      expect(names).to include(tenant_active.name)
    end
  end

  describe "with no data" do
    before { Tenant.destroy_all }

    it "handles empty state gracefully" do
      stats = described_class.call
      expect(stats.total_tenants).to eq(0)
      expect(stats.avg_company_size).to eq(0)
      expect(stats.churn_risk_tenants).to eq([])
      expect(stats.inactive_tenants).to eq([])
      expect(stats.recent_tenants).to eq([])
    end
  end
end
