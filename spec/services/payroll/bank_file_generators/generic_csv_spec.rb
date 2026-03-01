require "rails_helper"

RSpec.describe Payroll::BankFileGenerators::GenericCsv do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:run)     { create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026) }

  before { set_tenant(tenant) }

  let(:employee) do
    create(:employee, tenant: tenant,
           first_name: "Priya", last_name: "Patel",
           bank_name: "HDFC Bank",
           bank_account_number: "50100123456789",
           ifsc_code: "HDFC0001234")
  end

  let!(:payslip) do
    create(:payslip, tenant: tenant, payroll_run: run, employee: employee, net_pay: 42_500)
  end

  subject(:output) { described_class.new(payroll_run: run).call }

  it "returns a String" do
    expect(output).to be_a(String)
  end

  it "includes the header row" do
    expect(output).to include("Employee Code")
    expect(output).to include("Employee Name")
    expect(output).to include("Account Number")
    expect(output).to include("IFSC Code")
    expect(output).to include("Net Pay")
  end

  it "includes the employee code" do
    expect(output).to include(employee.employee_code)
  end

  it "includes the employee name" do
    expect(output).to include("Priya Patel")
  end

  it "includes the account number" do
    expect(output).to include("50100123456789")
  end

  it "includes the IFSC code" do
    expect(output).to include("HDFC0001234")
  end

  it "includes the net pay" do
    expect(output).to include("42500.0")
  end

  it "includes the narration with period label" do
    expect(output).to include("Salary March 2026")
  end

  it "uses sequential Sr No starting at 1" do
    rows = CSV.parse(output, headers: true)
    expect(rows.first["Sr No"]).to eq("1")
  end

  context "when employee has no bank_name" do
    before { employee.update_columns(bank_name: nil) }

    it "uses an em-dash placeholder" do
      expect(output).to include("—")
    end
  end

  context "with multiple employees" do
    let(:emp2) do
      create(:employee, tenant: tenant,
             first_name: "Rahul", last_name: "Sharma",
             bank_name: "SBI",
             bank_account_number: "20123456789",
             ifsc_code: "SBIN0001234")
    end

    before { create(:payslip, tenant: tenant, payroll_run: run, employee: emp2, net_pay: 55_000) }

    it "includes both employees" do
      expect(output).to include(employee.employee_code)
      expect(output).to include(emp2.employee_code)
    end

    it "assigns sequential Sr No" do
      rows = CSV.parse(output, headers: true)
      sr_nos = rows.map { |r| r["Sr No"].to_i }
      expect(sr_nos).to eq([ 1, 2 ])
    end
  end
end
