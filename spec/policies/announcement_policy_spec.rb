require "rails_helper"

RSpec.describe AnnouncementPolicy, type: :policy do
  let(:tenant)       { create(:tenant) }
  let(:admin_user)   { create(:user, :super_admin) }
  let(:hr_user)      { create(:user, :hr_admin) }
  let(:emp_user)     { create(:user, :employee) }
  let(:announcement) { create(:announcement, tenant: tenant) }

  before { set_tenant(tenant) }

  describe "for a super_admin" do
    subject { described_class.new(admin_user, announcement) }

    it { is_expected.to be_index }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
    it { is_expected.to be_publish }
    it { is_expected.to be_destroy }
  end

  describe "for an hr_admin" do
    subject { described_class.new(hr_user, announcement) }

    it { is_expected.to be_create }
    it { is_expected.to be_publish }
    it { is_expected.to be_destroy }
  end

  describe "for an employee" do
    subject { described_class.new(emp_user, announcement) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_publish }
    it { is_expected.not_to be_destroy }
  end
end
