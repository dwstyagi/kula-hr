require "rails_helper"

RSpec.describe LeaveRequestPolicy, type: :policy do
  let(:tenant)     { create(:tenant) }
  let(:admin_user) { create(:user, :super_admin) }
  let(:hr_user)    { create(:user, :hr_admin) }
  let(:emp_user)   { create(:user, :employee) }
  let(:other_user) { create(:user, :employee) }
  let(:employee)   { create(:employee, tenant: tenant, user: emp_user) }
  let(:other_emp)  { create(:employee, tenant: tenant, user: other_user) }
  let(:leave_type) { create(:leave_type, tenant: tenant) }
  let(:pending_req) do
    lr = build(:leave_request, :pending, tenant: tenant, employee: employee, leave_type: leave_type)
    lr.save(validate: false)
    lr
  end
  let(:other_req) do
    lr = build(:leave_request, :pending, tenant: tenant, employee: other_emp, leave_type: leave_type)
    lr.save(validate: false)
    lr
  end

  before { set_tenant(tenant) }

  describe "for a super_admin" do
    subject { described_class.new(admin_user, pending_req) }

    it { is_expected.to be_create }
    it { is_expected.to be_approve }
    it { is_expected.to be_reject }
    it { is_expected.to be_cancel }
  end

  describe "for an hr_admin" do
    subject { described_class.new(hr_user, pending_req) }

    it { is_expected.to be_approve }
    it { is_expected.to be_reject }
    it { is_expected.to be_cancel }
  end

  describe "for an employee (own pending request)" do
    subject { described_class.new(emp_user, pending_req) }

    it { is_expected.to be_create }
    it { is_expected.to be_cancel }
    it { is_expected.not_to be_approve }
    it { is_expected.not_to be_reject }
  end

  describe "for an employee (someone else's request)" do
    subject { described_class.new(emp_user, other_req) }

    it { is_expected.not_to be_cancel }
    it { is_expected.not_to be_approve }
  end

  describe "for an unauthenticated user" do
    subject { described_class.new(nil, pending_req) }

    it { is_expected.not_to be_create }
    it { is_expected.not_to be_cancel }
  end
end
