require "rails_helper"

RSpec.describe Employee, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    # build is fine for presence/inclusion — no DB needed
    subject { build(:employee, tenant: tenant) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:joining_date) }
    it { is_expected.to validate_presence_of(:employment_status) }
    it { is_expected.to validate_inclusion_of(:employment_status).in_array(Employee::EMPLOYMENT_STATUSES) }

    # Shoulda uniqueness matcher conflicts with acts_as_tenant scope — test manually
    describe "email uniqueness per tenant" do
      before { create(:employee, tenant: tenant, email: "taken@example.com") }

      it "rejects duplicate email within the same tenant" do
        duplicate = build(:employee, tenant: tenant, email: "taken@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).not_to be_empty
      end

      it "allows same email on a different tenant" do
        other_tenant = create(:tenant)
        ActsAsTenant.with_tenant(other_tenant) do
          other = build(:employee, tenant: other_tenant, email: "taken@example.com")
          expect(other).to be_valid
        end
      end
    end

    describe "employee_code uniqueness per tenant" do
      before { create(:employee, tenant: tenant, employee_code: "EMP9999", email: "a@example.com") }

      it "rejects duplicate code within the same tenant" do
        duplicate = build(:employee, tenant: tenant, employee_code: "EMP9999", email: "b@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:employee_code]).not_to be_empty
      end
    end
  end

  describe "associations" do
    # acts_as_tenant manages tenant scoping, not a standard Rails presence validation
    it { is_expected.to belong_to(:tenant).without_validating_presence }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:department).optional }
    it { is_expected.to belong_to(:designation).optional }
    it { is_expected.to belong_to(:reporting_manager).optional }
    it { is_expected.to have_many(:direct_reports) }
  end

  describe "employee_code auto-generation" do
    it "generates EMP0001 for the first employee" do
      employee = create(:employee, tenant: tenant)
      expect(employee.employee_code).to eq("EMP0001")
    end

    it "increments sequentially" do
      first  = create(:employee, tenant: tenant, email: "first@example.com")
      second = create(:employee, tenant: tenant, email: "second@example.com")
      expect(second.employee_code).to eq("EMP0002")
    end

    it "does not overwrite a pre-assigned code" do
      employee = create(:employee, tenant: tenant, employee_code: "EMP9999")
      expect(employee.employee_code).to eq("EMP9999")
    end

    it "scopes codes per tenant" do
      other_tenant = create(:tenant)
      ActsAsTenant.with_tenant(other_tenant) do
        create(:employee, tenant: other_tenant, email: "other@example.com")
      end

      employee = create(:employee, tenant: tenant, email: "mine@example.com")
      expect(employee.employee_code).to eq("EMP0001")
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      emp = build(:employee, first_name: "Jane", last_name: "Doe")
      expect(emp.full_name).to eq("Jane Doe")
    end
  end

  describe "#active?" do
    it "returns true for active status" do
      expect(build(:employee, employment_status: "active").active?).to be true
    end

    it "returns false for other statuses" do
      expect(build(:employee, employment_status: "probation").active?).to be false
    end
  end

  describe "optional user" do
    it "can be saved without a user (imported employees)" do
      employee = build(:employee, tenant: tenant, user: nil)
      expect(employee).to be_valid
    end
  end

  describe "scopes" do
    before do
      create(:employee, tenant: tenant, employment_status: "active",  email: "a@x.com")
      create(:employee, tenant: tenant, employment_status: "probation", email: "b@x.com")
      create(:employee, tenant: tenant, employment_status: "resigned", email: "c@x.com")
    end

    it ".active returns only active employees" do
      expect(Employee.active.count).to eq(1)
    end

    it ".probation returns only probation employees" do
      expect(Employee.probation.count).to eq(1)
    end
  end
end
