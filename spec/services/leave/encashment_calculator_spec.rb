require "rails_helper"

RSpec.describe Leave::EncashmentCalculator, type: :service do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant) }

  before { set_tenant(tenant) }

  def setup_salary(annual_ctc:, basic_percent:)
    structure  = create(:salary_structure, tenant: tenant)
    basic_comp = create(:salary_component, tenant: tenant, name: "Basic",
                        component_type: "earning", calculation_type: "percentage")
    create(:salary_structure_component, salary_structure: structure,
           salary_component: basic_comp, value: basic_percent)
    create(:employee_salary, tenant: tenant, employee: employee,
           salary_structure: structure, annual_ctc: annual_ctc, effective_to: nil)
  end

  describe "#call" do
    it "computes days × (basic_monthly ÷ 30)" do
      # annual_ctc=600_000, basic=40% → monthly_basic=20_000 → per_day=666.67
      # 6 days → 6 × 666.67 = 4000.00
      setup_salary(annual_ctc: 600_000, basic_percent: 40)
      result = described_class.new(employee: employee, number_of_days: 6).call
      expect(result).to eq(4000.00)
    end

    it "raises NoSalaryError when employee has no salary" do
      expect {
        described_class.new(employee: employee, number_of_days: 6).call
      }.to raise_error(Leave::EncashmentCalculator::NoSalaryError, /No salary assigned/)
    end

    it "raises NoSalaryError when salary structure has no Basic component" do
      structure = create(:salary_structure, tenant: tenant)
      create(:employee_salary, tenant: tenant, employee: employee,
             salary_structure: structure, annual_ctc: 600_000, effective_to: nil)

      expect {
        described_class.new(employee: employee, number_of_days: 6).call
      }.to raise_error(Leave::EncashmentCalculator::NoSalaryError, /No Basic component/)
    end
  end
end
