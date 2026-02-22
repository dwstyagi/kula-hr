require "rails_helper"

RSpec.describe LeaveBalance, type: :model do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:leave_type) { create(:leave_type, tenant: tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    subject { build(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type) }

    it { is_expected.to validate_presence_of(:financial_year) }
    it { is_expected.to validate_numericality_of(:total_days).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:used_days).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:remaining_days).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:carried_forward_days).is_greater_than_or_equal_to(0) }

    describe "uniqueness per employee, leave_type, financial_year" do
      before { create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type) }

      it "rejects duplicate balance for same employee+leave_type+year" do
        duplicate = build(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:employee_id]).not_to be_empty
      end

      it "allows same employee+leave_type in a different financial year" do
        bal = build(:leave_balance, tenant: tenant, employee: employee,
                    leave_type: leave_type, financial_year: "2020-21")
        expect(bal).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to belong_to(:employee) }
    it { is_expected.to belong_to(:leave_type) }
  end

  describe ".current_financial_year" do
    it "returns current FY in April–March format" do
      travel_to Date.new(2025, 8, 15) do
        expect(LeaveBalance.current_financial_year).to eq("2025-26")
      end
    end

    it "returns previous calendar year before April" do
      travel_to Date.new(2026, 2, 1) do
        expect(LeaveBalance.current_financial_year).to eq("2025-26")
      end
    end

    it "rolls over on April 1" do
      travel_to Date.new(2026, 4, 1) do
        expect(LeaveBalance.current_financial_year).to eq("2026-27")
      end
    end
  end

  describe "scopes" do
    let!(:current_bal) { create(:leave_balance, tenant: tenant, employee: employee,
                                 leave_type: leave_type,
                                 financial_year: LeaveBalance.current_financial_year) }
    let!(:old_bal) do
      other_type = create(:leave_type, tenant: tenant)
      create(:leave_balance, tenant: tenant, employee: employee,
             leave_type: other_type, financial_year: "2020-21")
    end

    it ".current returns only the current financial year" do
      expect(LeaveBalance.current).to include(current_bal)
      expect(LeaveBalance.current).not_to include(old_bal)
    end
  end
end
