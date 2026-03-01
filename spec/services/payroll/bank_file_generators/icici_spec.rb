require "rails_helper"

RSpec.describe Payroll::BankFileGenerators::Icici do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:run)     { create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026) }

  before { set_tenant(tenant) }

  let(:employee) do
    create(:employee, tenant: tenant,
           first_name: "Rajesh", last_name: "Iyer",
           bank_account_number: "123456789012",
           ifsc_code: "ICIC0001234")
  end

  let!(:payslip) do
    create(:payslip, tenant: tenant, payroll_run: run, employee: employee, net_pay: 62_500)
  end

  subject(:output) { described_class.new(payroll_run: run).call }

  it "returns a String" do
    expect(output).to be_a(String)
  end

  it "starts with the correct pipe-delimited header" do
    header = output.lines.first.strip
    expect(header).to eq("PAYMENT_DATE|BENE_ACCOUNT_NUMBER|BENE_NAME|BENE_BANK_IFSC|AMOUNT|PAYMENT_TYPE|REMARKS")
  end

  it "includes the account number" do
    expect(output).to include("123456789012")
  end

  it "includes the IFSC code" do
    expect(output).to include("ICIC0001234")
  end

  it "includes the net pay formatted to 2 decimal places" do
    expect(output).to include("62500.00")
  end

  it "includes NEFT as payment type" do
    expect(output).to include("|NEFT|")
  end

  it "includes the narration" do
    expect(output).to include("SAL-MAR-2026")
  end

  it "uses pipe delimiter in data rows" do
    data_line = output.lines.drop(1).first
    expect(data_line).to include("|")
    expect(data_line.split("|").length).to eq(7)
  end

  context "with employee name longer than 50 chars" do
    before do
      employee.update_columns(first_name: "Thiruvenkatanathan", last_name: "Subramaniam Narayanan Iyer")
    end

    it "truncates name to 50 characters" do
      data_line = output.lines.drop(1).first.strip
      parts     = data_line.split("|")
      expect(parts[2].length).to be <= 50
    end
  end

  context "when employee is missing bank details" do
    before { employee.update_columns(bank_account_number: nil) }

    it "excludes the employee" do
      data_lines = output.lines.drop(1)
      expect(data_lines).to be_empty
    end
  end
end
