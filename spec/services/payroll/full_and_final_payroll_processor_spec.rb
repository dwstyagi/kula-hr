require "rails_helper"

RSpec.describe Payroll::FullAndFinalPayrollProcessor do
  let(:tenant) { create(:tenant) }
  let(:settlement) do
    create(
      :full_and_final_settlement,
      tenant: tenant,
      earned_salary: 30_000,
      leave_encashment: 5_000,
      bonus: 10_000,
      notice_recovery: 8_000,
      tds_amount: 2_000
    )
  end

  before { set_tenant(tenant) }

  it "creates a settlement payslip and completes the run" do
    run = settlement.payroll_run
    result = described_class.new(payroll_run: run).call
    payslip = run.payslips.reload.sole

    expect(result.errors).to be_empty
    expect(payslip.gross_pay).to eq(45_000)
    expect(payslip.total_deductions).to eq(10_000)
    expect(payslip.net_pay).to eq(35_000)
    expect(payslip.line_items.pluck(:component_name)).to contain_exactly(
      "Salary until Last Working Date", "Leave Encashment", "Bonus / Incentive", "Notice Recovery", "TDS"
    )
    expect(settlement.reload.payslip).to eq(payslip)
    expect(run.reload).to be_processed
  end

  it "floors payment at zero and preserves the recoverable balance" do
    settlement.update!(asset_recovery: 50_000)

    described_class.new(payroll_run: settlement.payroll_run).call

    expect(settlement.payslip.reload.net_pay).to eq(0)
    expect(settlement.recoverable_amount).to eq(15_000)
  end

  it "clears the generated statement safely when HR reopens the calculation" do
    run = settlement.payroll_run
    described_class.new(payroll_run: run).call

    run.reprocess!

    expect(run.reload).to be_draft
    expect(run.payslips).to be_empty
    expect(settlement.reload.payslip).to be_nil
  end
end
