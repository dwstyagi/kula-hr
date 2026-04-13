require "rails_helper"

RSpec.describe Leave::MonthlyLeaveAccrualService do
  let(:tenant)  { create(:tenant) }
  let(:casual)  { create(:leave_type, :casual, tenant: tenant, annual_quota: 12) }
  let(:sick)    { create(:leave_type, :sick,   tenant: tenant, annual_quota: 6) }

  before { set_tenant(tenant) }

  describe "#call" do
    let(:employee) { create(:employee, tenant: tenant) }

    before do
      # Simulate the joining allocation (1 month's quota already credited)
      create(:leave_balance, tenant: tenant, employee: employee, leave_type: casual,
             total_days: 1.0, remaining_days: 1.0, used_days: 0)
      create(:leave_balance, tenant: tenant, employee: employee, leave_type: sick,
             total_days: 0.5, remaining_days: 0.5, used_days: 0)
    end

    subject(:service) { described_class.new(tenant: tenant) }

    it "adds each leave type's monthly quota to total_days and remaining_days" do
      service.call

      # casual: 12/12 = 1.0 added → 1.0 + 1.0 = 2.0
      expect(employee.leave_balances.find_by(leave_type: casual).reload.total_days).to eq(2.0)
      expect(employee.leave_balances.find_by(leave_type: casual).reload.remaining_days).to eq(2.0)

      # sick: 6/12 = 0.5 added → 0.5 + 0.5 = 1.0
      expect(employee.leave_balances.find_by(leave_type: sick).reload.total_days).to eq(1.0)
      expect(employee.leave_balances.find_by(leave_type: sick).reload.remaining_days).to eq(1.0)
    end

    it "does not change used_days" do
      service.call
      expect(employee.leave_balances.find_by(leave_type: casual).reload.used_days).to eq(0)
    end

    it "adds to remaining_days even when some days are already used" do
      employee.leave_balances.find_by(leave_type: casual).update!(used_days: 0.5, remaining_days: 0.5)
      service.call

      balance = employee.leave_balances.find_by(leave_type: casual).reload
      expect(balance.total_days).to eq(2.0)
      expect(balance.remaining_days).to eq(1.5)   # 0.5 remaining + 1.0 accrued
      expect(balance.used_days).to eq(0.5)         # unchanged
    end

    context "when an employee is on probation" do
      let(:employee) { create(:employee, :probation, tenant: tenant) }

      it "accrues for probation employees" do
        service.call
        expect(employee.leave_balances.find_by(leave_type: casual).reload.total_days).to eq(2.0)
      end
    end

    context "when an employee is resigned" do
      let(:employee) { create(:employee, :resigned, tenant: tenant) }

      it "skips resigned employees" do
        service.call
        expect(employee.leave_balances.find_by(leave_type: casual).reload.total_days).to eq(1.0)
      end
    end

    context "when all leave types are inactive" do
      before { casual.update!(is_active: false); sick.update!(is_active: false) }

      it "does nothing" do
        expect { service.call }.not_to raise_error
        expect(employee.leave_balances.find_by(leave_type: casual).reload.total_days).to eq(1.0)
      end
    end

    context "with multiple active employees" do
      let(:employee2) { create(:employee, tenant: tenant) }

      before do
        create(:leave_balance, tenant: tenant, employee: employee2, leave_type: casual,
               total_days: 1.0, remaining_days: 1.0, used_days: 0)
      end

      it "accrues for every employee with an existing balance" do
        service.call
        expect(employee.leave_balances.find_by(leave_type: casual).reload.total_days).to eq(2.0)
        expect(employee2.leave_balances.find_by(leave_type: casual).reload.total_days).to eq(2.0)
      end
    end

    context "tenant isolation" do
      let(:other_tenant)    { create(:tenant) }
      let(:other_employee)  { create(:employee, tenant: other_tenant) }
      let(:other_casual)    { create(:leave_type, :casual, tenant: other_tenant, annual_quota: 12) }

      before do
        ActsAsTenant.with_tenant(other_tenant) do
          create(:leave_balance, tenant: other_tenant, employee: other_employee,
                 leave_type: other_casual, total_days: 1.0, remaining_days: 1.0, used_days: 0)
        end
      end

      it "does not touch balances belonging to another tenant" do
        service.call   # runs scoped to tenant

        ActsAsTenant.with_tenant(other_tenant) do
          expect(other_employee.leave_balances.find_by(leave_type: other_casual).reload.total_days).to eq(1.0)
        end
      end
    end
  end

  describe ".run_for_all_tenants" do
    let(:tenant2) { create(:tenant, :active) }

    before do
      # tenant is "trial" by default — should be included
      create(:leave_balance, tenant: tenant, employee: create(:employee, tenant: tenant),
             leave_type: casual, total_days: 1.0, remaining_days: 1.0, used_days: 0)

      # tenant2 gets its own leave type and employee
      ActsAsTenant.with_tenant(tenant2) do
        t2_casual = create(:leave_type, :casual, tenant: tenant2, annual_quota: 12)
        t2_emp    = create(:employee, tenant: tenant2)
        create(:leave_balance, tenant: tenant2, employee: t2_emp,
               leave_type: t2_casual, total_days: 1.0, remaining_days: 1.0, used_days: 0)
      end
    end

    it "accrues leave for all active/trial tenants" do
      described_class.run_for_all_tenants

      # tenant (trial)
      ActsAsTenant.with_tenant(tenant) do
        expect(LeaveBalance.current.find_by(leave_type: casual).total_days).to eq(2.0)
      end

      # tenant2 (active)
      ActsAsTenant.with_tenant(tenant2) do
        expect(LeaveBalance.current.first.total_days).to eq(2.0)
      end
    end
  end
end
