require "rails_helper"

RSpec.describe EmployeeSalary, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:employee) }
    it { is_expected.to belong_to(:salary_structure) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:annual_ctc) }
    it { is_expected.to validate_numericality_of(:annual_ctc).is_greater_than_or_equal_to(100_000) }
    it { is_expected.to validate_presence_of(:effective_from) }

    it "validates effective_to is after effective_from" do
      employee = create(:employee, tenant: tenant)
      structure = create(:salary_structure, tenant: tenant)
      salary = build(:employee_salary,
        tenant: tenant,
        employee: employee,
        salary_structure: structure,
        effective_from: Date.today,
        effective_to: Date.yesterday
      )
      expect(salary).not_to be_valid
      expect(salary.errors[:effective_to]).to include("must be after effective from date")
    end

    it "allows nil effective_to (current salary)" do
      employee = create(:employee, tenant: tenant)
      structure = create(:salary_structure, tenant: tenant)
      salary = build(:employee_salary,
        tenant: tenant,
        employee: employee,
        salary_structure: structure,
        effective_from: Date.today,
        effective_to: nil
      )
      expect(salary).to be_valid
    end
  end

  describe "scopes" do
    let(:employee) { create(:employee, tenant: tenant) }
    let(:structure) { create(:salary_structure, tenant: tenant) }

    let!(:current_salary) do
      create(:employee_salary,
        tenant: tenant, employee: employee, salary_structure: structure,
        annual_ctc: 800_000, effective_from: Date.today, effective_to: nil
      )
    end

    let!(:old_salary) do
      create(:employee_salary,
        tenant: tenant, employee: employee, salary_structure: structure,
        annual_ctc: 600_000, effective_from: 1.year.ago.to_date, effective_to: Date.yesterday
      )
    end

    it ".current returns only records with nil effective_to" do
      expect(EmployeeSalary.current).to include(current_salary)
      expect(EmployeeSalary.current).not_to include(old_salary)
    end

    it ".history returns only records with non-nil effective_to" do
      expect(EmployeeSalary.history).to include(old_salary)
      expect(EmployeeSalary.history).not_to include(current_salary)
    end
  end

  describe "#current?" do
    it "returns true when effective_to is nil" do
      salary = build(:employee_salary, effective_to: nil)
      expect(salary.current?).to be true
    end

    it "returns false when effective_to is set" do
      salary = build(:employee_salary, effective_to: Date.today)
      expect(salary.current?).to be false
    end
  end

  describe "#monthly_ctc" do
    it "returns annual CTC divided by 12" do
      salary = build(:employee_salary, annual_ctc: 1_200_000)
      expect(salary.monthly_ctc).to eq(100_000.0)
    end

    it "rounds to 2 decimal places" do
      salary = build(:employee_salary, annual_ctc: 1_000_000)
      expect(salary.monthly_ctc).to eq(83_333.33)
    end
  end

  describe "Employee#current_salary" do
    let(:employee) { create(:employee, tenant: tenant) }
    let(:structure) { create(:salary_structure, tenant: tenant) }

    it "returns the current salary record" do
      current = create(:employee_salary,
        tenant: tenant, employee: employee, salary_structure: structure,
        annual_ctc: 800_000, effective_from: Date.today, effective_to: nil
      )
      create(:employee_salary,
        tenant: tenant, employee: employee, salary_structure: structure,
        annual_ctc: 600_000, effective_from: 1.year.ago.to_date, effective_to: Date.yesterday
      )

      expect(employee.current_salary).to eq(current)
    end

    it "returns nil when no salary is assigned" do
      expect(employee.current_salary).to be_nil
    end
  end
end
