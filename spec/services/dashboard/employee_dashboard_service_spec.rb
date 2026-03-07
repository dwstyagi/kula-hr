require "rails_helper"

RSpec.describe Dashboard::EmployeeDashboardService do
  let(:tenant) { create(:tenant, :active) }
  let(:employee) { create(:employee, tenant: tenant) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no payslips" do
      it "returns nil/zero values" do
        result = described_class.new(employee: employee).call

        expect(result.latest_payslip).to be_nil
        expect(result.mom_change).to be_nil
        expect(result.ytd_gross).to eq(0)
        expect(result.ytd_net).to eq(0)
      end
    end

    context "with payslips" do
      let!(:run1) { create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026) }
      let!(:run2) { create(:payroll_run, :approved, tenant: tenant, month: 2, year: 2026) }
      let!(:payslip1) do
        create(:payslip, tenant: tenant, employee: employee, payroll_run: run1,
               month: 1, year: 2026, gross_pay: 50_000, net_pay: 40_000, total_deductions: 10_000)
      end
      let!(:payslip2) do
        create(:payslip, tenant: tenant, employee: employee, payroll_run: run2,
               month: 2, year: 2026, gross_pay: 55_000, net_pay: 44_000, total_deductions: 11_000)
      end

      it "returns latest and previous payslips" do
        result = described_class.new(employee: employee).call

        expect(result.latest_payslip).to eq(payslip2)
        expect(result.previous_payslip).to eq(payslip1)
      end

      it "calculates MoM change" do
        result = described_class.new(employee: employee).call

        expected_change = ((44_000 - 40_000).to_f / 40_000 * 100).round(1)
        expect(result.mom_change).to eq(expected_change)
      end

      it "calculates YTD totals" do
        result = described_class.new(employee: employee).call

        expect(result.ytd_gross).to eq(105_000)
        expect(result.ytd_net).to eq(84_000)
      end

      context "with deduction line items" do
        before do
          create(:payslip_line_item, :deduction, payslip: payslip1,
                 component_name: "PF", amount: 1_800)
          create(:payslip_line_item, :deduction, payslip: payslip2,
                 component_name: "PF", amount: 1_800)
          create(:payslip_line_item, :deduction, payslip: payslip1,
                 component_name: "TDS", amount: 5_000)
        end

        it "returns YTD component totals" do
          result = described_class.new(employee: employee).call

          expect(result.ytd_pf).to eq(3_600)
          expect(result.ytd_tds).to eq(5_000)
        end
      end
    end
  end
end
