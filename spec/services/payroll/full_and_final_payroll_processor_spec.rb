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

    expect(settlement.reload.payslip.net_pay).to eq(0)
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
  it "generates one payslip per employee in a batch settlement" do
    run = settlement.payroll_run
    other = create(:employee, tenant: tenant)
    second = create(:full_and_final_settlement, tenant: tenant, payroll_run: run,
                    employee: other, earned_salary: 12_000, leave_encashment: 0,
                    notice_recovery: 2_000)

    result = described_class.new(payroll_run: run).call
    run.reload

    expect(result.processed).to contain_exactly(settlement.employee_id, other.id)
    expect(run.payslips.count).to eq(2)
    expect(run.total_employees).to eq(2)
    expect(run.processed_employees).to eq(2)
    expect(run.total_net_pay).to eq(run.payslips.sum(:net_pay))
    expect(second.reload.payslip.employee).to eq(other)
    expect(settlement.reload.payslip.employee).to eq(settlement.employee)
  end

  it "settles the rest of the batch when one employee fails" do
    run = settlement.payroll_run
    other = create(:employee, tenant: tenant)
    create(:full_and_final_settlement, tenant: tenant, payroll_run: run, employee: other)

    allow_any_instance_of(FullAndFinalSettlement).to receive(:update!).and_wrap_original do |m, *args|
      raise ActiveRecord::RecordInvalid, FullAndFinalSettlement.new if m.receiver.employee_id == other.id

      m.call(*args)
    end

    result = described_class.new(payroll_run: run).call
    run.reload

    expect(result.processed).to eq([ settlement.employee_id ])
    expect(result.skipped).to eq([ other.id ])
    expect(result.errors.size).to eq(1)
    expect(run.processed_employees).to eq(1)
    expect(run).to be_processed
  end
end
