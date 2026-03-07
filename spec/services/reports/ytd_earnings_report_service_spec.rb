require "rails_helper"

RSpec.describe Reports::YtdEarningsReportService do
  let(:tenant) { create(:tenant, :active) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no approved runs in FY" do
      it "returns empty rows" do
        result = described_class.new(financial_year: "2025-26").call
        expect(result.rows).to be_empty
      end
    end

    context "with approved runs in FY 2025-26 (Apr 2025 - Mar 2026)" do
      let!(:dept) { create(:department, tenant: tenant, name: "Engineering") }
      let!(:run_apr) { create(:payroll_run, :approved, tenant: tenant, month: 4, year: 2025) }
      let!(:run_jan) { create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026) }
      let!(:employee) { create(:employee, tenant: tenant, department: dept) }

      let!(:ps1) do
        create(:payslip, tenant: tenant, payroll_run: run_apr, employee: employee,
               month: 4, year: 2025, gross_pay: 50_000, total_deductions: 5_000, net_pay: 45_000)
      end
      let!(:ps2) do
        create(:payslip, tenant: tenant, payroll_run: run_jan, employee: employee,
               month: 1, year: 2026, gross_pay: 55_000, total_deductions: 6_000, net_pay: 49_000)
      end

      before do
        create(:payslip_line_item, payslip: ps1, component_name: "Basic", component_type: "earning", amount: 25_000)
        create(:payslip_line_item, :deduction, payslip: ps1, component_name: "PF", amount: 1_800)
        create(:payslip_line_item, payslip: ps2, component_name: "Basic", component_type: "earning", amount: 27_500)
        create(:payslip_line_item, :deduction, payslip: ps2, component_name: "PF", amount: 1_800)
      end

      it "aggregates across FY months" do
        result = described_class.new(financial_year: "2025-26").call

        expect(result.rows.size).to eq(1)
        row = result.rows.first
        expect(row.employee_code).to eq(employee.employee_code)
        expect(row.total_gross).to eq(105_000)
        expect(row.total_net).to eq(94_000)
        expect(row.months_count).to eq(2)
      end

      it "tracks component totals" do
        result = described_class.new(financial_year: "2025-26").call
        row = result.rows.first

        expect(row.component_totals["earning:Basic"]).to eq(52_500)
        expect(row.component_totals["deduction:PF"]).to eq(3_600)
      end

      it "generates CSV with all components" do
        result = described_class.new(financial_year: "2025-26").call
        csv = result.to_csv

        expect(csv).to include("Basic")
        expect(csv).to include("PF")
        expect(csv).to include(employee.employee_code)
      end

      it "calculates summary" do
        result = described_class.new(financial_year: "2025-26").call

        expect(result.summary[:employee_count]).to eq(1)
        expect(result.summary[:total_gross]).to eq(105_000)
      end
    end
  end
end
