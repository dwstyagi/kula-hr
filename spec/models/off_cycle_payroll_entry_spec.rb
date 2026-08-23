require "rails_helper"

RSpec.describe OffCyclePayrollEntry, type: :model do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :hr_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:run) do
    PayrollRun.new(
      tenant: tenant,
      initiated_by: user,
      run_type: "bonus",
      title: "Annual Bonus",
      payment_date: Date.new(2026, 8, 15),
      month: 8,
      year: 2026
    )
  end

  before { set_tenant(tenant) }

  it "calculates net amount" do
    entry = run.off_cycle_payroll_entries.build(
      tenant: tenant, employee: employee, gross_amount: 50_000, tds_amount: 7_500
    )
    expect(entry.net_amount).to eq(42_500)
  end

  it "rejects TDS greater than gross" do
    entry = run.off_cycle_payroll_entries.build(
      tenant: tenant, employee: employee, gross_amount: 10_000, tds_amount: 10_001
    )
    expect(entry).not_to be_valid
    expect(entry.errors[:tds_amount]).to include("cannot exceed gross amount")
  end

  it "rejects entries on regular payroll" do
    regular = build(:payroll_run, tenant: tenant, initiated_by: user)
    entry = described_class.new(
      tenant: tenant, payroll_run: regular, employee: employee,
      gross_amount: 10_000, tds_amount: 0
    )
    expect(entry).not_to be_valid
    expect(entry.errors[:payroll_run]).to include("must be a bonus or additional-payment run")
  end
end
