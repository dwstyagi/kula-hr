require "rails_helper"

RSpec.describe SalaryStructure, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "associations" do
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to have_many(:salary_structure_components).dependent(:destroy) }
    it { is_expected.to have_many(:salary_components).through(:salary_structure_components) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name scoped to tenant" do
      create(:salary_structure, tenant: tenant, name: "Standard CTC")
      duplicate = build(:salary_structure, tenant: tenant, name: "Standard CTC")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows same name across different tenants" do
      create(:salary_structure, tenant: tenant, name: "Standard CTC")
      other_tenant = create(:tenant)
      ActsAsTenant.with_tenant(other_tenant) do
        other = build(:salary_structure, tenant: other_tenant, name: "Standard CTC")
        expect(other).to be_valid
      end
    end
  end

  describe "scopes" do
    let!(:active_structure) { create(:salary_structure, tenant: tenant) }
    let!(:inactive_structure) { create(:salary_structure, :inactive, tenant: tenant) }

    it ".active returns only active structures" do
      expect(SalaryStructure.active).to include(active_structure)
      expect(SalaryStructure.active).not_to include(inactive_structure)
    end
  end

  describe "#component_count" do
    it "returns the number of components in the structure" do
      structure = create(:salary_structure, tenant: tenant)
      comp1 = create(:salary_component, tenant: tenant, name: "Basic")
      comp2 = create(:salary_component, tenant: tenant, name: "HRA")

      create(:salary_structure_component, salary_structure: structure, salary_component: comp1, value: 40)
      create(:salary_structure_component, salary_structure: structure, salary_component: comp2, value: 20)

      expect(structure.component_count).to eq(2)
    end
  end

  describe "#total_percentage" do
    it "sums percentage values of percentage-type components only" do
      structure = create(:salary_structure, tenant: tenant)
      pct_comp = create(:salary_component, :percentage, tenant: tenant, name: "Basic")
      flat_comp = create(:salary_component, tenant: tenant, name: "Conveyance", calculation_type: "flat")

      create(:salary_structure_component, salary_structure: structure, salary_component: pct_comp, value: 40)
      create(:salary_structure_component, salary_structure: structure, salary_component: flat_comp, value: 1600)

      expect(structure.total_percentage).to eq(40)
    end
  end
end
