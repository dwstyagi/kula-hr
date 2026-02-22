require "rails_helper"

RSpec.describe SalaryStructureComponent, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "associations" do
    it { is_expected.to belong_to(:salary_structure) }
    it { is_expected.to belong_to(:salary_component) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value).is_greater_than(0) }

    it "validates uniqueness of salary_component per structure" do
      structure = create(:salary_structure, tenant: tenant)
      component = create(:salary_component, tenant: tenant)
      create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 40)

      duplicate = build(:salary_structure_component, salary_structure: structure, salary_component: component, value: 50)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:salary_component_id]).to include("has already been added to this structure")
    end

    it "allows same component in different structures" do
      component = create(:salary_component, tenant: tenant)
      structure1 = create(:salary_structure, tenant: tenant, name: "Structure A")
      structure2 = create(:salary_structure, tenant: tenant, name: "Structure B")

      create(:salary_structure_component, salary_structure: structure1, salary_component: component, value: 40)
      other = build(:salary_structure_component, salary_structure: structure2, salary_component: component, value: 50)
      expect(other).to be_valid
    end
  end

  describe "delegation" do
    it "delegates name and component_type to salary_component" do
      component = create(:salary_component, tenant: tenant, name: "Basic", component_type: "earning")
      structure = create(:salary_structure, tenant: tenant)
      ssc = create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 40)

      expect(ssc.name).to eq("Basic")
      expect(ssc.component_type).to eq("earning")
    end
  end
end
