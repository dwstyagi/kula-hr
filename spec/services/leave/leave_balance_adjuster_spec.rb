require "rails_helper"

RSpec.describe Leave::LeaveBalanceAdjuster do
  let(:tenant)     { create(:tenant) }
  let(:employee)   { create(:employee, tenant: tenant) }
  let(:leave_type) { create(:leave_type, :casual, tenant: tenant) }
  let(:balance) do
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type,
           total_days: 12, used_days: 0, remaining_days: 12)
  end

  before { set_tenant(tenant) }

  # A guaranteed weekday (3 weeks from now, Monday)
  let(:future_monday) { Date.today.next_occurring(:monday) + 14 }

  describe "#debit!" do
    let(:leave_request) do
      lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                 from_date: future_monday, to_date: future_monday)
      lr.save(validate: false)
      lr
    end

    before { balance }   # ensure balance exists

    it "deducts days from the remaining balance" do
      described_class.new(leave_request: leave_request).debit!
      expect(balance.reload.remaining_days).to eq(11.0)
      expect(balance.reload.used_days).to eq(1.0)
    end

    it "raises InsufficientBalance when days exceed remaining" do
      balance.update!(remaining_days: 0)
      expect {
        described_class.new(leave_request: leave_request).debit!
      }.to raise_error(Leave::LeaveBalanceAdjuster::InsufficientBalance, /Insufficient/)
    end

    it "skips deduction for LOP leave type" do
      lop_type = create(:leave_type, :lop, tenant: tenant)
      lop_request = build(:leave_request, tenant: tenant, employee: employee, leave_type: lop_type,
                          from_date: Date.today + 7, to_date: Date.today + 7)
      lop_request.save(validate: false)

      expect {
        described_class.new(leave_request: lop_request).debit!
      }.not_to change { balance.reload.remaining_days }
    end

    it "raises InsufficientBalance when no balance record exists" do
      balance.destroy
      expect {
        described_class.new(leave_request: leave_request).debit!
      }.to raise_error(Leave::LeaveBalanceAdjuster::InsufficientBalance)
    end
  end

  describe "#credit!" do
    let(:leave_request) do
      # Mon–Wed = 3 business days
      lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: leave_type,
                 from_date: future_monday, to_date: future_monday + 2)
      lr.save(validate: false)
      lr
    end

    before { balance.update!(used_days: 3, remaining_days: 9) }

    it "returns days to the remaining balance" do
      described_class.new(leave_request: leave_request).credit!
      expect(balance.reload.remaining_days).to eq(12.0)
      expect(balance.reload.used_days).to eq(0.0)
    end

    it "does not allow used_days to go below 0" do
      balance.update!(used_days: 0, remaining_days: 12)
      leave_request.update_columns(number_of_days: 5)

      described_class.new(leave_request: leave_request).credit!
      expect(balance.reload.used_days).to eq(0)
    end

    it "skips credit for LOP leave type" do
      lop_type = create(:leave_type, :lop, tenant: tenant)
      lop_request = build(:leave_request, :approved, tenant: tenant, employee: employee,
                          leave_type: lop_type, from_date: Date.today + 7, to_date: Date.today + 7)
      lop_request.save(validate: false)

      expect {
        described_class.new(leave_request: lop_request).credit!
      }.not_to change { balance.reload.remaining_days }
    end
  end
end
