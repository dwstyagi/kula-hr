require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:tenant_users).dependent(:destroy) }
    it { is_expected.to have_many(:tenants).through(:tenant_users) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
  end

  describe "#full_name" do
    it "returns first and last name" do
      user = build(:user, first_name: "John", last_name: "Doe")
      expect(user.full_name).to eq("John Doe")
    end
  end

  describe "#assign_role" do
    let(:user) { create(:user) }

    it "assigns a new role" do
      user.assign_role(:super_admin)
      expect(user.has_role?(:super_admin)).to be true
    end

    it "clears previous roles before assigning" do
      user.assign_role(:super_admin)
      user.assign_role(:employee)

      expect(user.has_role?(:super_admin)).to be false
      expect(user.has_role?(:employee)).to be true
    end

    it "ensures only one role at a time" do
      user.assign_role(:hr_admin)
      expect(user.roles.count).to eq(1)
    end
  end
end
