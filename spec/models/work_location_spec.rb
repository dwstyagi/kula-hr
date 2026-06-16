require "rails_helper"

RSpec.describe WorkLocation, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to have_many(:holidays).dependent(:nullify) }
    it { is_expected.to have_many(:employees).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:work_location, tenant: tenant) }

    it { is_expected.to validate_presence_of(:name) }

    it "validates name uniqueness scoped to tenant" do
      create(:work_location, tenant: tenant, name: "Mumbai")
      dup = build(:work_location, tenant: tenant, name: "Mumbai")
      expect(dup).not_to be_valid
    end

    it "allows the same name in a different tenant" do
      create(:work_location, tenant: tenant, name: "Mumbai")
      other_tenant = create(:tenant)
      ActsAsTenant.with_tenant(other_tenant) do
        expect(build(:work_location, tenant: other_tenant, name: "Mumbai")).to be_valid
      end
    end
  end

  describe ".active" do
    it "returns only active locations" do
      active   = create(:work_location, tenant: tenant)
      inactive = create(:work_location, :inactive, tenant: tenant)
      expect(WorkLocation.active).to include(active)
      expect(WorkLocation.active).not_to include(inactive)
    end
  end
end
