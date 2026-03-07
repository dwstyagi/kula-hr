require "rails_helper"

RSpec.describe Reports::PfMonthlyReportService do
  let(:tenant) { create(:tenant, :active) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no payroll run" do
      it "returns empty rows" do
        result = described_class.new(month: 1, year: 2026).call
        expect(result.rows).to be_empty
      end
    end

    context "with approved run and PF data" do
      let!(:setting) do
        create(:payroll_setting, tenant: tenant, pf_enabled: true,
               pf_employee_rate: 12, pf_employer_rate: 12, pf_wage_ceiling: 15_000,
               pf_edli_rate: 0.5)
      end
      let!(:run) { create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026) }
      let!(:employee) { create(:employee, tenant: tenant, pf_applicable: true, uan_number: "100123456789") }
      let!(:payslip) { create(:payslip, tenant: tenant, payroll_run: run, employee: employee, gross_pay: 50_000) }
      let!(:basic_item) { create(:payslip_line_item, payslip: payslip, component_name: "Basic", component_type: "earning", amount: 25_000) }

      it "generates PF rows" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.rows.size).to eq(1)
        row = result.rows.first
        expect(row.uan).to eq("100123456789")
        expect(row.epf_wages).to eq(15_000) # capped at ceiling
        expect(row.epf_ee).to eq(1_800) # 15000 * 0.12
      end

      it "generates ECR format" do
        result = described_class.new(month: 1, year: 2026).call
        ecr = result.to_ecr

        expect(ecr).to include("100123456789")
        expect(ecr).to include("|")
      end

      it "calculates summary" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.summary[:employee_count]).to eq(1)
        expect(result.summary[:total_epf_ee]).to eq(1_800)
      end
    end
  end
end
