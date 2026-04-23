require "rails_helper"

RSpec.describe Leave::YearEndProcessingService, type: :service do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  let!(:earned_type) do
    create(:leave_type, :earned, tenant: tenant,
           annual_quota: 15, carry_forward: true, max_carry_forward: 10)
  end
  let!(:casual_type) do
    create(:leave_type, :casual, tenant: tenant,
           annual_quota: 12, carry_forward: false, max_carry_forward: 0)
  end
  let!(:employee) { create(:employee, tenant: tenant, employment_status: :active) }

  let(:current_fy) { LeaveBalance.current_financial_year }
  let(:service)    { described_class.new(tenant: tenant) }

  def next_fy
    today = Date.today
    year  = today.month >= 4 ? today.year : today.year - 1
    "#{year + 1}-#{(year + 2).to_s.last(2)}"
  end

  describe "#call" do
    context "when employee has remaining earned leave" do
      before do
        create(:leave_balance, tenant: tenant, employee: employee,
               leave_type: earned_type, financial_year: current_fy,
               total_days: 15, used_days: 8, remaining_days: 7)
        create(:leave_balance, tenant: tenant, employee: employee,
               leave_type: casual_type, financial_year: current_fy,
               total_days: 12, used_days: 3, remaining_days: 9)
      end

      it "carries forward min(max_carry_forward, remaining_days) for carry-forward types" do
        service.call
        balance = LeaveBalance.find_by(employee: employee, leave_type: earned_type, financial_year: next_fy)
        expect(balance).to be_present
        expect(balance.carried_forward_days).to eq(7) # min(10, 7)
      end

      it "seeds new FY with first month accrual + carried days" do
        service.call
        balance = LeaveBalance.find_by(employee: employee, leave_type: earned_type, financial_year: next_fy)
        first_month = (15 / 12.0).round(2)
        expect(balance.total_days.to_f).to be_within(0.1).of(first_month + 7)
        expect(balance.remaining_days.to_f).to be_within(0.1).of(first_month + 7)
        expect(balance.used_days).to eq(0)
      end

      it "does not carry forward for non-carry-forward types" do
        service.call
        balance = LeaveBalance.find_by(employee: employee, leave_type: casual_type, financial_year: next_fy)
        expect(balance.carried_forward_days).to eq(0)
        first_month = (12 / 12.0).round(2)
        expect(balance.total_days).to eq(first_month)
      end
    end

    context "when remaining days exceed max_carry_forward" do
      before do
        create(:leave_balance, tenant: tenant, employee: employee,
               leave_type: earned_type, financial_year: current_fy,
               total_days: 15, used_days: 0, remaining_days: 15)
      end

      it "caps carried days at max_carry_forward" do
        service.call
        balance = LeaveBalance.find_by(employee: employee, leave_type: earned_type, financial_year: next_fy)
        expect(balance.carried_forward_days).to eq(10) # min(10, 15) = 10
      end
    end

    context "when employee has no current FY balance" do
      it "creates new FY record with only first month accrual and zero carry" do
        service.call
        balance = LeaveBalance.find_by(employee: employee, leave_type: earned_type, financial_year: next_fy)
        first_month = (15 / 12.0).round(2)
        expect(balance.total_days.to_f).to be_within(0.1).of(first_month)
        expect(balance.carried_forward_days).to eq(0)
      end
    end

    context "when employee is not active or probation" do
      let!(:resigned_employee) { create(:employee, tenant: tenant, employment_status: :resigned) }

      before do
        create(:leave_balance, tenant: tenant, employee: resigned_employee,
               leave_type: earned_type, financial_year: current_fy,
               total_days: 15, used_days: 0, remaining_days: 15)
      end

      it "skips resigned employees" do
        service.call
        balance = LeaveBalance.find_by(employee: resigned_employee, leave_type: earned_type, financial_year: next_fy)
        expect(balance).to be_nil
      end
    end

    context "when called twice (re-run safety)" do
      before do
        create(:leave_balance, tenant: tenant, employee: employee,
               leave_type: earned_type, financial_year: current_fy,
               total_days: 15, used_days: 5, remaining_days: 10)
      end

      it "does not create duplicate records on re-run" do
        service.call
        expect { service.call }.not_to change {
          LeaveBalance.where(financial_year: next_fy).count
        }
      end
    end
  end

  describe ".run_for_all_tenants" do
    it "processes all trial and active tenants" do
      create(:leave_balance, tenant: tenant, employee: employee,
             leave_type: earned_type, financial_year: current_fy,
             total_days: 15, used_days: 5, remaining_days: 10)

      described_class.run_for_all_tenants

      balance = ActsAsTenant.with_tenant(tenant) do
        LeaveBalance.find_by(employee: employee, leave_type: earned_type, financial_year: next_fy)
      end
      expect(balance).to be_present
    end
  end
end
