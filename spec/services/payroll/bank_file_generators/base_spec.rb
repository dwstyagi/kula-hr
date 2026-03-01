require "rails_helper"

RSpec.describe Payroll::BankFileGenerators::Base do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:run)     { create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026) }

  before { set_tenant(tenant) }

  # Use GenericCsv as a concrete subclass to exercise Base behaviour
  def build_generator
    Payroll::BankFileGenerators::GenericCsv.new(payroll_run: run)
  end

  def create_payslip(employee)
    create(:payslip, tenant: tenant, payroll_run: run, employee: employee,
           net_pay: 45_000)
  end

  describe "#employees_missing_bank_details" do
    context "when all employees have bank details" do
      let!(:emp) do
        e = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234")
        create_payslip(e)
        e
      end

      it "returns an empty array" do
        expect(build_generator.employees_missing_bank_details).to be_empty
      end
    end

    context "when some employees are missing bank details" do
      let!(:emp_ok) do
        e = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234")
        create_payslip(e)
        e
      end

      let!(:emp_missing) do
        e = create(:employee, tenant: tenant, bank_account_number: nil, ifsc_code: nil)
        create_payslip(e)
        e
      end

      it "returns the employee with missing details" do
        missing = build_generator.employees_missing_bank_details
        expect(missing).to include(emp_missing)
        expect(missing).not_to include(emp_ok)
      end
    end

    context "when only ifsc_code is missing" do
      let!(:emp) do
        e = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: nil)
        create_payslip(e)
        e
      end

      it "flags the employee as missing" do
        expect(build_generator.employees_missing_bank_details).to include(emp)
      end
    end

    context "when payslip net_pay is 0 (excluded from file)" do
      let!(:emp) do
        e = create(:employee, tenant: tenant, bank_account_number: nil, ifsc_code: nil)
        create(:payslip, tenant: tenant, payroll_run: run, employee: e, net_pay: 0)
        e
      end

      it "does not flag zero-pay employees (they are excluded from @payslips)" do
        expect(build_generator.employees_missing_bank_details).to be_empty
      end
    end
  end

  describe "#call — detect_missing! filters eligible payslips" do
    let!(:emp_ok) do
      e = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234",
                 bank_name: "HDFC Bank")
      create_payslip(e)
      e
    end

    let!(:emp_missing) do
      e = create(:employee, tenant: tenant, bank_account_number: nil, ifsc_code: nil)
      create_payslip(e)
      e
    end

    it "only includes eligible employees in the generated file" do
      output = build_generator.call
      expect(output).to include(emp_ok.employee_code)
      expect(output).not_to include(emp_missing.employee_code)
    end
  end
end
