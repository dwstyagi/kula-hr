require "rails_helper"

RSpec.describe Payroll::PayslipPdfDocument, :with_cache do
  let(:tenant) { create(:tenant, :active) }
  let(:employee) { create(:employee, tenant: tenant, department: create(:department, tenant: tenant)) }
  let(:run) { create(:payroll_run, :approved, tenant: tenant, month: 5, year: 2026) }
  let(:slip) { create(:payslip, :locked, tenant: tenant, employee: employee, payroll_run: run, month: 5, year: 2026) }
  let!(:setting) { create(:payroll_setting, tenant: tenant) }
  let!(:line) { create(:payslip_line_item, payslip: slip, component_name: "Basic") }

  before do
    set_tenant(tenant)
    allow(Payroll::PayslipPdfGenerator).to receive(:new).and_return(instance_double(Payroll::PayslipPdfGenerator, call: "%PDF-cached"))
  end

  def render_document
    described_class.call(payslip: Payslip.find(slip.id))
  end

  it "reuses a render for unchanged data" do
    expect(render_document).to eq("%PDF-cached")
    expect(render_document).to eq("%PDF-cached")
    expect(Payroll::PayslipPdfGenerator).to have_received(:new).once
  end

  {
    "line items" => -> { line.update!(amount: line.amount + 100) },
    "employee details" => -> { employee.update!(bank_name: "Updated Bank") },
    "company details" => -> { tenant.update!(name: "Updated Company") },
    "payroll settings" => -> { setting.update!(employer_pf_in_ctc: !setting.employer_pf_in_ctc) },
    "department name" => -> { employee.department.update!(name: "Updated Department") },
    "pay date" => -> { run.update_column(:approved_at, Time.current) },
    "prior payslips" => -> {
      prior = create(:payroll_run, :approved, tenant: tenant, month: 4, year: 2026)
      create(:payslip, tenant: tenant, employee: employee, payroll_run: prior, month: 4, year: 2026)
    }
  }.each do |dependency, change|
    it "invalidates cached PDFs when #{dependency} change" do
      render_document
      instance_exec(&change)
      render_document
      expect(Payroll::PayslipPdfGenerator).to have_received(:new).twice
    end
  end
end
