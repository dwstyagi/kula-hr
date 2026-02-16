require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:tenant) { create(:tenant) }
  let(:record) { tenant }

  describe "super_admin" do
    let(:user) { create(:user, :super_admin) }
    subject { described_class.new(user, record) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_new }
    it { is_expected.to be_update }
    it { is_expected.to be_edit }
    it { is_expected.to be_destroy }
  end

  describe "hr_admin" do
    let(:user) { create(:user, :hr_admin) }
    subject { described_class.new(user, record) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
    it { is_expected.not_to be_destroy }
  end

  describe "employee" do
    let(:user) { create(:user, :employee) }
    subject { described_class.new(user, record) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_destroy }
  end

  describe "unauthenticated user (nil)" do
    subject { described_class.new(nil, record) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_destroy }
  end
end
