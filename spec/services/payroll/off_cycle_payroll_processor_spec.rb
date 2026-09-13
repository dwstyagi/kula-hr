require "rails_helper"

RSpec.describe Payroll::OffCyclePayrollProcessor do
  let(:tenant) { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:run) do
    PayrollRun.create!(
      tenant: tenant,
      initiated_by: hr_user,
      run_type: "bonus",
      title: "Performance Bonus",
      payment_date: Date.new(2026, 8, 15),
      month: 8,
      year: 2026,
      off_cycle_payroll_entries_attributes: [
        { tenant: tenant, employee: employee, gross_amount: 50_000, tds_amount: 8_000 }
      ]
    )
  end

  before { set_tenant(tenant) }

  it "creates a separate payslip without attendance" do
    result = described_class.new(payroll_run: run).call
    payslip = run.payslips.first

    expect(result.errors).to be_empty
    expect(payslip.gross_pay).to eq(50_000)
    expect(payslip.total_deductions).to eq(8_000)
    expect(payslip.net_pay).to eq(42_000)
    expect(payslip.total_working_days).to eq(0)
    expect(payslip.line_items.pluck(:component_name)).to contain_exactly("Performance Bonus", "TDS")
  end

  it "moves the run to processed and updates totals" do
    described_class.new(payroll_run: run).call
    run.reload

    expect(run).to be_processed
    expect(run.processed_employees).to eq(1)
    expect(run.total_gross).to eq(50_000)
    expect(run.total_net_pay).to eq(42_000)
  end

  it "reports zero processed when every entry fails" do
    allow(Payslip).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Payslip.new))

    result = described_class.new(payroll_run: run).call
    run.reload

    expect(result.processed).to be_empty
    expect(result.errors.size).to eq(1)
    expect(run.processed_employees).to eq(0)
    expect(run.payslips).to be_empty
  end

  it "refuses to process a regular payroll run" do
    regular = create(:payroll_run, tenant: tenant, initiated_by: hr_user)
    expect { described_class.new(payroll_run: regular).call }
      .to raise_error(ArgumentError, /only bonus and additional-payment/)
  end
end
