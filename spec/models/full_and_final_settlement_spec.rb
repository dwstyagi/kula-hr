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
  describe "#close_out_employee!" do
    let(:employee) { create(:employee, tenant: tenant, joining_date: Date.new(2025, 1, 1)) }

    it "moves an in-service employee to resigned and stamps the last working date" do
      settlement = create(:full_and_final_settlement, tenant: tenant, employee: employee)
      employee.update!(employment_status: "active")

      settlement.close_out_employee!

      expect(employee.reload.employment_status).to eq("resigned")
      expect(employee.last_working_date).to eq(settlement.last_working_date)
    end

    it "does not relabel a terminated employee as resigned" do
      employee.update!(employment_status: "terminated")
      settlement = create(:full_and_final_settlement, tenant: tenant, employee: employee)

      settlement.close_out_employee!

      expect(employee.reload.employment_status).to eq("terminated")
      expect(employee.last_working_date).to eq(settlement.last_working_date)
    end

    it "removes the employee from later regular payroll eligibility" do
      settlement = create(:full_and_final_settlement, tenant: tenant, employee: employee)
      settlement.close_out_employee!
      lwd = settlement.last_working_date
      following = lwd.next_month

      eligible = Payroll::ReadinessCheck.eligible_employees(
        month: following.month, year: following.year, tenant: tenant
      )

      expect(eligible).not_to include(employee)
    end
  end
  describe "multiple settlements in one run" do
    it "allows several employees in a single settlement run" do
      first = create(:full_and_final_settlement, tenant: tenant)
      run = first.payroll_run
      second = build(:full_and_final_settlement, tenant: tenant, payroll_run: run,
                     employee: create(:employee, tenant: tenant))

      expect(second).to be_valid
      expect { second.save! }.to change { run.full_and_final_settlements.count }.by(1)
    end

    it "refuses the same employee twice in one run" do
      first = create(:full_and_final_settlement, tenant: tenant)
      duplicate = build(:full_and_final_settlement, tenant: tenant,
                        payroll_run: first.payroll_run, employee: first.employee)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:employee_id]).to include("is already being settled in this run")
    end
  end
end
