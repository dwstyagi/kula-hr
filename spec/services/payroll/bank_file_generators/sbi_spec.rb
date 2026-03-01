require "rails_helper"

RSpec.describe Payroll::BankFileGenerators::Sbi do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:run)     { create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 2, year: 2026) }

  before { set_tenant(tenant) }

  let(:employee) do
    create(:employee, tenant: tenant,
           first_name: "Rahul", last_name: "Sharma",
           bank_account_number: "20123456789012",
           ifsc_code: "SBIN0001234")
  end

  let!(:payslip) do
    create(:payslip, tenant: tenant, payroll_run: run, employee: employee, net_pay: 38_750)
  end

  subject(:output) { described_class.new(payroll_run: run).call }

  it "returns a String" do
    expect(output).to be_a(String)
  end

  it "starts with the correct comma-delimited CMP header" do
    header = output.lines.first.strip
    expect(header).to eq("TXN_DATE,BENE_AC_NO,BENE_NAME,BENE_IFSC,AMOUNT,REMARKS")
  end

  it "includes the account number" do
    expect(output).to include("20123456789012")
  end

  it "includes the IFSC code" do
    expect(output).to include("SBIN0001234")
  end

  it "includes the net pay" do
    expect(output).to include("38750")
  end

  it "includes the narration" do
    expect(output).to include("SAL-FEB-2026")
  end

  it "uses comma delimiter in data rows" do
    data_line = output.lines.drop(1).first.strip
    parts     = data_line.split(",")
    expect(parts.length).to eq(6)
  end

  it "formats the date in DD-MON-YYYY uppercase format" do
    data_line  = output.lines.drop(1).first.strip
    date_field = data_line.split(",").first
    expect(date_field).to match(/\A\d{2}-[A-Z]{3}-\d{4}\z/)
  end

  context "with employee name longer than 35 chars" do
    before do
      employee.update_columns(first_name: "Venkatanarasimharaju", last_name: "Krishnaswamy")
    end

    it "truncates name to 35 characters" do
      data_line  = output.lines.drop(1).first.strip
      parts      = data_line.split(",")
      expect(parts[2].length).to be <= 35
    end
  end

  context "when employee is missing bank details" do
    before { employee.update_columns(ifsc_code: nil) }

    it "excludes the employee from the output" do
      data_lines = output.lines.drop(1)
      expect(data_lines).to be_empty
    end
  end
end
