require "rails_helper"

RSpec.describe Payroll::BankFileGenerators::Hdfc do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:run)     { create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026) }

  before { set_tenant(tenant) }

  let(:employee) do
    create(:employee, tenant: tenant,
           first_name: "Sunita", last_name: "Rao",
           bank_account_number: "50100123456789",
           ifsc_code: "HDFC0001234")
  end

  let!(:payslip) do
    create(:payslip, tenant: tenant, payroll_run: run, employee: employee, net_pay: 45_000)
  end

  subject(:output) { described_class.new(payroll_run: run).call }

  it "returns a String" do
    expect(output).to be_a(String)
  end

  it "starts with a header line beginning with H~" do
    header = output.lines.first.strip
    expect(header).to start_with("H~")
  end

  it "includes NEFT product code in header" do
    expect(output.lines.first).to include("~NEFT~")
  end

  it "includes CORP001 in header" do
    expect(output.lines.first).to include("CORP001")
  end

  it "includes batch code with month and year" do
    expect(output).to include("BATCH012026")
  end

  it "includes total net pay in header" do
    expect(output.lines.first).to include("45000")
  end

  it "has a detail line beginning with D~" do
    detail_line = output.lines.find { |l| l.strip.start_with?("D~") }
    expect(detail_line).to be_present
  end

  it "includes account number in detail line" do
    expect(output).to include("50100123456789")
  end

  it "includes IFSC code in detail line" do
    expect(output).to include("HDFC0001234")
  end

  it "includes the net pay amount in detail line" do
    expect(output).to include("45000")
  end

  it "includes the narration" do
    expect(output).to include("SAL-JAN-2026")
  end

  it "uses tilde delimiter throughout" do
    output.lines.each do |line|
      next if line.strip.empty?
      expect(line).to include("~")
    end
  end

  context "with employee name longer than 40 chars" do
    before do
      employee.update_columns(first_name: "Venkatanarasimharajuvaripeta", last_name: "Krishnaswamy")
    end

    it "truncates name to 40 characters" do
      detail = output.lines.find { |l| l.strip.start_with?("D~") }
      parts  = detail.strip.split("~")
      name_field = parts[2]
      expect(name_field.length).to be <= 40
    end
  end

  context "when employee is missing bank details" do
    before { employee.update_columns(bank_account_number: nil, ifsc_code: nil) }

    it "excludes the employee from the output" do
      expect(output).not_to include("SUNITA")
      detail_lines = output.lines.select { |l| l.strip.start_with?("D~") }
      expect(detail_lines).to be_empty
    end
  end
end
