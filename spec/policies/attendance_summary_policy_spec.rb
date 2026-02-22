require "rails_helper"

RSpec.describe AttendanceSummaryPolicy, type: :policy do
  let(:tenant)     { create(:tenant) }
  let(:employee)   { create(:employee, tenant: tenant) }
  let(:admin_user) { create(:user, :super_admin) }
  let(:hr_user)    { create(:user, :hr_admin) }
  let(:emp_user)   { create(:user, :employee) }
  let(:draft_summary) do
    create(:attendance_summary, :draft, tenant: tenant, employee: employee)
  end
  let(:locked_summary) do
    create(:attendance_summary, :locked, tenant: tenant, employee: employee,
           month: Date.today.prev_month.month, year: Date.today.prev_month.year)
  end

  before { set_tenant(tenant) }

  describe "for a super_admin on a draft summary" do
    subject { described_class.new(admin_user, draft_summary) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_update }
    it { is_expected.to be_generate }
    it { is_expected.to be_lock_month }
    it { is_expected.to be_download_template }
    it { is_expected.to be_upload_template }
  end

  describe "for a super_admin on a locked summary" do
    subject { described_class.new(admin_user, locked_summary) }

    it { is_expected.to be_show }
    it { is_expected.not_to be_update }
  end

  describe "for an hr_admin" do
    subject { described_class.new(hr_user, draft_summary) }

    it { is_expected.to be_index }
    it { is_expected.to be_update }
  end

  describe "for an hr_admin on a locked summary" do
    subject { described_class.new(hr_user, locked_summary) }

    it { is_expected.not_to be_update }
  end

  describe "for an employee" do
    subject { described_class.new(emp_user, draft_summary) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_generate }
  end
end
