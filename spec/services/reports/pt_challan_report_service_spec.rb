require "rails_helper"

RSpec.describe Reports::PtChallanReportService do
  let(:tenant) { create(:tenant, :active) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no payroll run" do
      it "returns empty rows" do
        result = described_class.new(month: 1, year: 2026).call
        expect(result.rows).to be_empty
      end
    end

    context "with approved run and PT data" do
      let!(:setting) do
        create(:payroll_setting, tenant: tenant, pt_enabled: true, pt_state: "maharashtra")
      end
      let!(:slab) do
        create(:professional_tax_slab, tenant: tenant, state: "maharashtra",
               salary_from: 0, salary_to: 100_000, tax_amount: 200)
      end
      let!(:run) { create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026) }
      let!(:employee) { create(:employee, tenant: tenant, pt_applicable: true) }
      let!(:payslip) do
        create(:payslip, tenant: tenant, payroll_run: run, employee: employee, gross_pay: 50_000)
      end
      let!(:pt_item) do
        create(:payslip_line_item, :deduction, payslip: payslip,
               component_name: "Professional Tax", amount: 200)
      end

      it "generates PT rows" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.rows.size).to eq(1)
        expect(result.rows.first.pt_amount).to eq(200)
      end

      it "generates slab summaries" do
        result = described_class.new(month: 1, year: 2026).call

        expect(result.slab_summaries.size).to eq(1)
        expect(result.slab_summaries.first.employee_count).to eq(1)
      end

      it "generates CSV" do
        result = described_class.new(month: 1, year: 2026).call
        csv = result.to_csv

        expect(csv).to include("PT Amount")
        expect(csv).to include("Slab Summary")
      end
    end
  end
end
