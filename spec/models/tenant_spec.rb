require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:tenant_users).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:tenant_users) }
    it { is_expected.to have_many(:departments).dependent(:destroy) }
    it { is_expected.to have_many(:designations).dependent(:destroy) }
    it { is_expected.to have_many(:salary_components).dependent(:destroy) }
    it { is_expected.to have_many(:leave_types).dependent(:destroy) }
    it { is_expected.to have_many(:professional_tax_slabs).dependent(:destroy) }
    it { is_expected.to have_many(:payroll_runs).dependent(:destroy) }
    it { is_expected.to have_one(:payroll_setting).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:tenant) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:subdomain) }
    it { is_expected.to validate_uniqueness_of(:subdomain).case_insensitive }
    it { is_expected.to validate_length_of(:subdomain).is_at_least(3).is_at_most(63) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[trial active suspended cancelled]) }

    context "subdomain format" do
      it "allows valid subdomains" do
        %w[acme my-company company123].each do |sub|
          tenant = build(:tenant, subdomain: sub)
          expect(tenant).to be_valid
        end
      end

      it "rejects invalid subdomains" do
        %w[-start end- -both- has_underscore HAS.DOTS].each do |sub|
          tenant = build(:tenant, subdomain: sub)
          expect(tenant).not_to be_valid
        end
      end
    end

    context "reserved subdomains" do
      it "rejects reserved subdomains" do
        %w[www admin api app].each do |sub|
          tenant = build(:tenant, subdomain: sub)
          expect(tenant).not_to be_valid
          expect(tenant.errors[:subdomain]).to include("is reserved")
        end
      end
    end

    context "GSTIN format" do
      it "accepts valid GSTIN" do
        tenant = build(:tenant, gstin: "27AABCU9603R1ZM")
        expect(tenant).to be_valid
      end

      it "rejects invalid GSTIN" do
        tenant = build(:tenant, gstin: "INVALID")
        expect(tenant).not_to be_valid
        expect(tenant.errors[:gstin]).to include("is not a valid GSTIN")
      end

      it "allows blank GSTIN" do
        tenant = build(:tenant, gstin: "")
        expect(tenant).to be_valid
      end
    end

    context "PAN format" do
      it "accepts valid PAN" do
        tenant = build(:tenant, pan: "AABCU9603R")
        expect(tenant).to be_valid
      end

      it "rejects invalid PAN" do
        tenant = build(:tenant, pan: "INVALID")
        expect(tenant).not_to be_valid
        expect(tenant.errors[:pan]).to include("is not a valid PAN")
      end

      it "allows blank PAN" do
        tenant = build(:tenant, pan: "")
        expect(tenant).to be_valid
      end
    end
  end

  describe "scopes" do
    let!(:trial_tenant) { create(:tenant, status: "trial") }
    let!(:active_tenant) { create(:tenant, :active) }
    let!(:suspended_tenant) { create(:tenant, :suspended) }

    it ".active returns active tenants" do
      expect(Tenant.active).to contain_exactly(active_tenant)
    end

    it ".trial returns trial tenants" do
      expect(Tenant.trial).to contain_exactly(trial_tenant)
    end

    it ".suspended returns suspended tenants" do
      expect(Tenant.suspended).to contain_exactly(suspended_tenant)
    end
  end

  describe "callbacks" do
    it "normalizes subdomain to lowercase" do
      tenant = create(:tenant, subdomain: "ACME123")
      expect(tenant.subdomain).to eq("acme123")
    end
  end

  describe "#write_allowed?" do
    it "returns true for active tenants" do
      expect(build(:tenant, :active).write_allowed?).to be true
    end

    it "returns true for trial tenants with fewer than #{Tenant::TRIAL_PAYROLL_RUN_LIMIT} approved runs" do
      tenant = create(:tenant, status: "trial")
      expect(tenant.write_allowed?).to be true
    end

    it "returns false for suspended tenants" do
      expect(build(:tenant, :suspended).write_allowed?).to be false
    end

    it "returns false for trial tenants once payroll run limit is reached" do
      tenant = create(:tenant, status: "trial")
      hr_user = create(:user, :hr_admin)
      Tenant::TRIAL_PAYROLL_RUN_LIMIT.times do |i|
        ActsAsTenant.with_tenant(tenant) do
          create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: i + 1, year: 2026)
        end
      end
      expect(tenant.write_allowed?).to be false
    end
  end

  describe "#trial_payroll_runs_used" do
    let(:tenant) { create(:tenant, status: "trial") }
    let(:hr_user) { create(:user, :hr_admin) }

    it "counts approved and paid payroll runs" do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
        create(:payroll_run, :paid, tenant: tenant, initiated_by: hr_user, month: 2, year: 2026)
        create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026) # draft
      end
      expect(tenant.trial_payroll_runs_used).to eq(2)
    end

    it "returns 0 when no approved runs exist" do
      expect(tenant.trial_payroll_runs_used).to eq(0)
    end
  end

  describe "#trial_payroll_runs_exhausted?" do
    let(:tenant) { create(:tenant, status: "trial") }
    let(:hr_user) { create(:user, :hr_admin) }

    it "returns false when under the limit" do
      expect(tenant.trial_payroll_runs_exhausted?).to be false
    end

    it "returns true when approved runs reach the limit" do
      Tenant::TRIAL_PAYROLL_RUN_LIMIT.times do |i|
        ActsAsTenant.with_tenant(tenant) do
          create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: i + 1, year: 2026)
        end
      end
      expect(tenant.trial_payroll_runs_exhausted?).to be true
    end

    it "returns false for active tenants regardless of run count" do
      tenant_active = create(:tenant, :active)
      Tenant::TRIAL_PAYROLL_RUN_LIMIT.times do |i|
        ActsAsTenant.with_tenant(tenant_active) do
          create(:payroll_run, :approved, tenant: tenant_active, initiated_by: hr_user, month: i + 1, year: 2026)
        end
      end
      expect(tenant_active.trial_payroll_runs_exhausted?).to be false
    end
  end
end
