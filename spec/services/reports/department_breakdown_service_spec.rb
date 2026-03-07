require "rails_helper"

RSpec.describe Reports::DepartmentBreakdownService do
  let(:tenant) { create(:tenant, :active) }
  let(:dept1) { create(:department, tenant: tenant, name: "Engineering") }
  let(:dept2) { create(:department, tenant: tenant, name: "Sales") }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no approved payroll run" do
      it "returns empty rows" do
        result = described_class.new(month: 1, year: 2026).call
        expect(result.rows).to be_empty
      end
    end

    context "with approved payroll run" do
      let!(:run) { create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026) }
      let!(:emp1) { create(:employee, tenant: tenant, department: dept1) }
      let!(:emp2) { create(:employee, tenant: tenant, department: dept1) }
      let!(:emp3) { create(:employee, tenant: tenant, department: dept2) }

      let!(:ps1) { create(:payslip, tenant: tenant, payroll_run: run, employee: emp1, gross_pay: 50_000, net_pay: 40_000, total_deductions: 10_000, employer_pf: 1_800, employer_esi: 0) }
      let!(:ps2) { create(:payslip, tenant: tenant, payroll_run: run, employee: emp2, gross_pay: 60_000, net_pay: 48_000, total_deductions: 12_000, employer_pf: 1_800, employer_esi: 0) }
      let!(:ps3) { create(:payslip, tenant: tenant, payroll_run: run, employee: emp3, gross_pay: 40_000, net_pay: 35_000, total_deductions: 5_000, employer_pf: 1_800, employer_esi: 500) }

      it "groups by department" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.rows.size).to eq(2)
        eng = result.rows.find { |r| r.department_name == "Engineering" }
        expect(eng.employee_count).to eq(2)
        expect(eng.total_gross).to eq(110_000)
      end

      it "calculates summary totals" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.summary[:employee_count]).to eq(3)
        expect(result.summary[:total_gross]).to eq(150_000)
      end

      it "generates CSV" do
        result = described_class.new(month: 1, year: 2026).call
        csv = result.to_csv

        expect(csv).to include("Department")
        expect(csv).to include("Engineering")
        expect(csv).to include("Sales")
      end
    end
  end
end
