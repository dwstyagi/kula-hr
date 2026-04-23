require "rails_helper"

RSpec.describe LeaveType, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    subject { build(:leave_type, tenant: tenant) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_numericality_of(:annual_quota).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:max_carry_forward).is_greater_than_or_equal_to(0) }

    describe "max_carry_forward when carry_forward is enabled" do
      it "is invalid when max_carry_forward is 0" do
        lt = build(:leave_type, tenant: tenant, carry_forward: true, max_carry_forward: 0, annual_quota: 15)
        expect(lt).not_to be_valid
        expect(lt.errors[:max_carry_forward]).to include("must be at least 1 day when carry forward is enabled")
      end

      it "is invalid when max_carry_forward equals annual_quota" do
        lt = build(:leave_type, tenant: tenant, carry_forward: true, max_carry_forward: 15, annual_quota: 15)
        expect(lt).not_to be_valid
        expect(lt.errors[:max_carry_forward]).to include("must be less than the annual quota (15 days)")
      end

      it "is invalid when max_carry_forward exceeds annual_quota" do
        lt = build(:leave_type, tenant: tenant, carry_forward: true, max_carry_forward: 20, annual_quota: 15)
        expect(lt).not_to be_valid
      end

      it "is valid when max_carry_forward is between 1 and annual_quota" do
        lt = build(:leave_type, tenant: tenant, carry_forward: true, max_carry_forward: 10, annual_quota: 15)
        expect(lt).to be_valid
      end

      it "does not apply when carry_forward is false" do
        lt = build(:leave_type, tenant: tenant, carry_forward: false, max_carry_forward: 0, annual_quota: 12)
        expect(lt).to be_valid
      end
    end

    describe "name uniqueness per tenant" do
      before { create(:leave_type, :casual, tenant: tenant) }

      it "rejects duplicate name within tenant" do
        duplicate = build(:leave_type, :casual, tenant: tenant)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).not_to be_empty
      end

      it "allows same name on a different tenant" do
        other = create(:tenant)
        ActsAsTenant.with_tenant(other) do
          expect(build(:leave_type, :casual, tenant: other)).to be_valid
        end
      end
    end
  end

  describe "associations" do
    # acts_as_tenant makes the tenant association optional at the DB level
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to have_many(:leave_balances).dependent(:destroy) }
    it { is_expected.to have_many(:leave_requests) }
  end

  describe "scopes" do
    let!(:active_paid)   { create(:leave_type, tenant: tenant, is_active: true,  is_paid: true)  }
    let!(:active_lop)    { create(:leave_type, :lop, tenant: tenant, is_active: true)  }
    let!(:inactive_type) { create(:leave_type, tenant: tenant, is_active: false, is_paid: true)  }

    it ".active returns only active leave types" do
      expect(LeaveType.active).to include(active_paid, active_lop)
      expect(LeaveType.active).not_to include(inactive_type)
    end

    it ".paid returns only paid leave types" do
      expect(LeaveType.paid).to include(active_paid)
      expect(LeaveType.paid).not_to include(active_lop)
    end

    it ".lop returns only unpaid leave types" do
      expect(LeaveType.lop).to include(active_lop)
      expect(LeaveType.lop).not_to include(active_paid)
    end
  end

  describe "#lop?" do
    it "returns true for unpaid leave types" do
      expect(build(:leave_type, :lop, tenant: tenant).lop?).to be true
    end

    it "returns false for paid leave types" do
      expect(build(:leave_type, :casual, tenant: tenant).lop?).to be false
    end
  end
end
