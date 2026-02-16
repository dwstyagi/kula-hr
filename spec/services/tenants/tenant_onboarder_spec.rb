require "rails_helper"

RSpec.describe Tenants::TenantOnboarder do
  let(:form) do
    SignupForm.new(
      company_name: "Test Company",
      subdomain: "testco",
      first_name: "John",
      last_name: "Doe",
      email: "john@testco.com",
      password: "password123",
      password_confirmation: "password123",
      state: "Maharashtra"
    )
  end

  describe ".call" do
    context "with valid form data" do
      let(:result) { described_class.call(form) }

      it "returns a successful result" do
        expect(result.success?).to be true
      end

      it "creates a tenant" do
        expect { described_class.call(form) }.to change(Tenant, :count).by(1)
      end

      it "creates a user" do
        expect { described_class.call(form) }.to change(User, :count).by(1)
      end

      it "creates a tenant_user link" do
        expect { described_class.call(form) }.to change(TenantUser, :count).by(1)
      end

      it "assigns super_admin role to the user" do
        result = described_class.call(form)
        expect(result.user.has_role?(:super_admin)).to be true
      end

      it "creates a payroll setting" do
        expect { described_class.call(form) }.to change(PayrollSetting, :count).by(1)
      end

      it "creates 12 salary components" do
        expect { described_class.call(form) }.to change(SalaryComponent, :count).by(12)
      end

      it "creates 4 leave types" do
        expect { described_class.call(form) }.to change(LeaveType, :count).by(4)
      end

      it "creates professional tax slabs for Maharashtra" do
        expect { described_class.call(form) }.to change(ProfessionalTaxSlab, :count).by(4)
      end

      it "sets tenant status to trial" do
        result = described_class.call(form)
        expect(result.tenant.status).to eq("trial")
      end
    end

    context "with Karnataka state" do
      let(:karnataka_form) do
        SignupForm.new(
          company_name: "KA Company",
          subdomain: "kaco",
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@kaco.com",
          password: "password123",
          password_confirmation: "password123",
          state: "Karnataka"
        )
      end

      it "creates 2 professional tax slabs" do
        expect { described_class.call(karnataka_form) }.to change(ProfessionalTaxSlab, :count).by(2)
      end
    end

    context "when tenant creation fails" do
      before do
        create(:tenant, subdomain: "testco")
      end

      it "returns a failed result" do
        result = described_class.call(form)
        expect(result.success?).to be false
      end

      it "does not create a user" do
        expect { described_class.call(form) }.not_to change(User, :count)
      end

      it "rolls back all changes" do
        expect { described_class.call(form) }.not_to change(PayrollSetting, :count)
      end
    end
  end
end
