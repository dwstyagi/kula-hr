require "rails_helper"

RSpec.describe SalaryComponent, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:component_type) }
    it { is_expected.to validate_presence_of(:calculation_type) }
    it { is_expected.to validate_numericality_of(:sort_order).only_integer }

    it "validates uniqueness of name scoped to tenant" do
      create(:salary_component, tenant: tenant, name: "Basic")
      duplicate = build(:salary_component, tenant: tenant, name: "Basic")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows same name across different tenants" do
      create(:salary_component, tenant: tenant, name: "Basic")
      other_tenant = create(:tenant)
      ActsAsTenant.with_tenant(other_tenant) do
        other = build(:salary_component, tenant: other_tenant, name: "Basic")
        expect(other).to be_valid
      end
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:component_type).backed_by_column_of_type(:string).with_values(earning: "earning", deduction: "deduction", employer_contribution: "employer_contribution") }
    it { is_expected.to define_enum_for(:calculation_type).backed_by_column_of_type(:string).with_values(flat: "flat", percentage: "percentage") }
  end

  describe "scopes" do
    let!(:earning) { create(:salary_component, :earning, tenant: tenant) }
    let!(:deduction) { create(:salary_component, :deduction, tenant: tenant) }
    let!(:employer_contrib) { create(:salary_component, :employer_contribution, tenant: tenant) }
    let!(:inactive) { create(:salary_component, :inactive, tenant: tenant) }

    it ".active returns only active components" do
      expect(SalaryComponent.active).to include(earning, deduction, employer_contrib)
      expect(SalaryComponent.active).not_to include(inactive)
    end

    it ".earnings returns only earnings" do
      expect(SalaryComponent.earnings).to include(earning)
      expect(SalaryComponent.earnings).not_to include(deduction, employer_contrib)
    end

    it ".deductions returns only deductions" do
      expect(SalaryComponent.deductions).to include(deduction)
      expect(SalaryComponent.deductions).not_to include(earning, employer_contrib)
    end

    it ".employer_contributions returns only employer contributions" do
      expect(SalaryComponent.employer_contributions).to include(employer_contrib)
      expect(SalaryComponent.employer_contributions).not_to include(earning, deduction)
    end
  end
end
