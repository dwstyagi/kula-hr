require "rails_helper"

RSpec.describe PlatformAdmin, type: :model do
  describe "validations" do
    subject { build(:platform_admin) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to have_secure_password }
  end

  describe "#full_name" do
    it "returns first and last name" do
      admin = build(:platform_admin, first_name: "Platform", last_name: "Admin")
      expect(admin.full_name).to eq("Platform Admin")
    end
  end

  describe "email normalization" do
    it "downcases and strips email before validation" do
      admin = create(:platform_admin, email: "  ADMIN@KULAHR.COM  ")
      expect(admin.email).to eq("admin@kulahr.com")
    end
  end
end
