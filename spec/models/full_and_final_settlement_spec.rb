require "rails_helper"

RSpec.describe FullAndFinalSettlement, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  it "calculates earnings, deductions, net pay, and recovery" do
    settlement = build(
      :full_and_final_settlement,
      tenant: tenant,
      earned_salary: 30_000,
      leave_encashment: 5_000,
      bonus: 10_000,
      notice_recovery: 8_000,
      tds_amount: 2_000
    )

    expect(settlement.total_earnings).to eq(45_000)
    expect(settlement.total_deductions).to eq(10_000)
    expect(settlement.net_pay).to eq(35_000)
    expect(settlement.recoverable_amount).to eq(0)

    settlement.asset_recovery = 50_000
    expect(settlement.net_pay).to eq(0)
    expect(settlement.recoverable_amount).to eq(15_000)
  end

  it "rejects a payment date before the last working date" do
    settlement = build(:full_and_final_settlement, tenant: tenant)
    settlement.payroll_run.payment_date = settlement.last_working_date - 1.day

    expect(settlement).not_to be_valid
    expect(settlement.errors[:base]).to include("Payment date cannot be before the last working date")
  end

  it "prevents a second non-rejected settlement for the employee" do
    existing = create(:full_and_final_settlement, tenant: tenant)
    duplicate = build(:full_and_final_settlement, tenant: tenant, employee: existing.employee)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:employee]).to include("already has an open or completed F&F settlement")
  end
end
