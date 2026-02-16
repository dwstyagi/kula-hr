require "rails_helper"

RSpec.describe TenantUser, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:tenant) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { create(:tenant_user) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:tenant_id).with_message("is already a member of this tenant") }
  end
end
