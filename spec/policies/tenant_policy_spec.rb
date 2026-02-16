require "rails_helper"

RSpec.describe TenantPolicy do
  let(:tenant) { create(:tenant) }

  describe "super_admin" do
    let(:user) { create(:user, :super_admin) }
    subject { described_class.new(user, tenant) }

    it { is_expected.to be_show }
    it { is_expected.to be_update }
  end

  describe "hr_admin" do
    let(:user) { create(:user, :hr_admin) }
    subject { described_class.new(user, tenant) }

    it { is_expected.not_to be_show }
    it { is_expected.not_to be_update }
  end

  describe "employee" do
    let(:user) { create(:user, :employee) }
    subject { described_class.new(user, tenant) }

    it { is_expected.not_to be_show }
    it { is_expected.not_to be_update }
  end
end
