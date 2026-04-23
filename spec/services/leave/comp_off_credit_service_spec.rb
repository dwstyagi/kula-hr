require "rails_helper"

RSpec.describe Leave::CompOffCreditService, type: :service do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant, employment_status: :active) }

  before { set_tenant(tenant) }

  let!(:comp_off_type) do
    create(:leave_type, tenant: tenant, name: "Comp Off", code: "CO",
           annual_quota: 0, carry_forward: false, max_carry_forward: 0)
  end

  let(:request) do
    create(:comp_off_request, :approved, tenant: tenant, employee: employee,
           expiry_date: nil)
  end

  describe "#call" do
    it "credits 1 day to the comp-off leave balance" do
      described_class.new(comp_off_request: request).call
      balance = LeaveBalance.find_by(employee: employee, leave_type: comp_off_type)
      expect(balance.remaining_days).to eq(1)
      expect(balance.total_days).to eq(1)
    end

    it "sets expiry_date to 7 days from today" do
      described_class.new(comp_off_request: request).call
      expect(request.reload.expiry_date).to eq(Date.today + 7)
    end

    it "increments existing balance" do
      create(:leave_balance, tenant: tenant, employee: employee,
             leave_type: comp_off_type,
             financial_year: LeaveBalance.current_financial_year,
             total_days: 1, used_days: 0, remaining_days: 1)

      described_class.new(comp_off_request: request).call
      balance = LeaveBalance.find_by(employee: employee, leave_type: comp_off_type)
      expect(balance.remaining_days).to eq(2)
    end

    it "raises if comp-off leave type does not exist" do
      comp_off_type.destroy!
      expect {
        described_class.new(comp_off_request: request).call
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
