require "rails_helper"

RSpec.describe Payroll::PayslipPdfGenerator do
  let(:tenant) { create(:tenant, name: "Acme Corporation") }

  around { |ex| ActsAsTenant.with_tenant(tenant) { ex.run } }

  def payslip_with_lines(month:, year:, gross:, net:, employee: nil)
    run = create(:payroll_run, tenant: tenant, month: month, year: year)
    employee ||= create(:employee, tenant: tenant, pan_number: "AAHAK6789M",
                        bank_account_number: "50100456789010", ifsc_code: "HDFC0009012")
    ps = create(:payslip, tenant: tenant, payroll_run: run, employee: employee,
                month: month, year: year, gross_pay: gross,
                total_deductions: gross - net, net_pay: net)
    create(:payslip_line_item, payslip: ps, component_name: "Basic", component_type: "earning", amount: gross)
    create(:payslip_line_item, :deduction, payslip: ps, component_name: "PF",  amount: 1_800)
    create(:payslip_line_item, :deduction, payslip: ps, component_name: "TDS", amount: gross - net - 1_800)
    ps
  end

  describe "#call" do
    it "renders a valid, non-trivial PDF" do
      ps  = payslip_with_lines(month: 6, year: 2026, gross: 92_307, net: 84_597)
      pdf = described_class.new(payslip: ps).call

      expect(pdf).to start_with("%PDF-")
      expect(pdf.bytesize).to be > 5_000
    end

    it "does not raise when optional employee fields are blank" do
      ps = payslip_with_lines(month: 6, year: 2026, gross: 50_000, net: 45_000)
      ps.employee.update_columns(designation_id: nil, department_id: nil,
                                 uan_number: nil, bank_account_number: nil, ifsc_code: nil)

      expect { described_class.new(payslip: ps).call }.not_to raise_error
    end
  end

  describe "year-to-date totals" do
    it "sums gross/net/PF/TDS across the FY up to and including the slip month" do
      emp = create(:employee, tenant: tenant)
      april = payslip_with_lines(month: 4, year: 2026, gross: 100_000, net: 93_200, employee: emp)
      may   = payslip_with_lines(month: 5, year: 2026, gross: 100_000, net: 93_200, employee: emp)
      # an out-of-range slip (previous FY: Mar 2026) must be excluded
      payslip_with_lines(month: 3, year: 2026, gross: 100_000, net: 93_200, employee: emp)

      ytd = described_class.new(payslip: may).send(:ytd)

      expect(ytd[:gross]).to eq(200_000)       # april + may, not march
      expect(ytd[:net]).to eq(186_400)
      expect(ytd[:pf]).to eq(3_600)            # 1800 x 2
      expect(ytd[:tds]).to eq(april.total_deductions - 1_800 + (may.total_deductions - 1_800))
    end
  end
end
