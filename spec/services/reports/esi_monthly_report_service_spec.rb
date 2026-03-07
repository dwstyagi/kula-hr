require "rails_helper"

RSpec.describe Reports::EsiMonthlyReportService do
  let(:tenant) { create(:tenant, :active) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no payroll run" do
      it "returns empty rows" do
        result = described_class.new(month: 1, year: 2026).call
        expect(result.rows).to be_empty
      end
    end

    context "with approved run and ESI data" do
      let!(:setting) do
        create(:payroll_setting, tenant: tenant, esi_enabled: true,
               esi_employee_rate: 0.75, esi_employer_rate: 3.25)
      end
      let!(:run) { create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026) }
      let!(:employee) { create(:employee, tenant: tenant) }
      let!(:payslip) do
        create(:payslip, tenant: tenant, payroll_run: run, employee: employee,
               gross_pay: 15_000, employer_esi: 488)
      end
      let!(:esi_item) do
        create(:payslip_line_item, :deduction, payslip: payslip,
               component_name: "ESI", amount: 113)
      end

      it "generates ESI rows" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.rows.size).to eq(1)
        row = result.rows.first
        expect(row.employee_contribution).to eq(113)
        expect(row.employer_contribution).to eq(488)
      end

      it "generates CSV" do
        result = described_class.new(month: 1, year: 2026).call
        csv = result.to_csv

        expect(csv).to include("Employee Code")
        expect(csv).to include("Employer Contribution")
      end

      it "calculates summary" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.summary[:total_ee]).to eq(113)
        expect(result.summary[:total_er]).to eq(488)
      end
    end
  end
end
