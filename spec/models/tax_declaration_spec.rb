require "rails_helper"

RSpec.describe TaxDeclaration, type: :model do
  let(:tenant) { create(:tenant, :active) }

  # New Regime is the statutory default in India — a declaration created
  # without an explicit regime choice (e.g. an employee's first portal visit
  # via find_or_create_by!) must not silently fall back to Old Regime.
  it "defaults to new_regime when not explicitly set" do
    employee = ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) }

    declaration = ActsAsTenant.with_tenant(tenant) do
      TaxDeclaration.create!(tenant: tenant, employee: employee, financial_year: "2026-27")
    end

    expect(declaration).to be_regime_new_regime
  end

  describe "#completeness_percent" do
    it "is 0 for an untouched draft" do
      declaration = ActsAsTenant.with_tenant(tenant) do
        create(:tax_declaration, tenant: tenant, status: :draft, monthly_rent: 0,
               home_loan_interest: 0, home_loan_principal: 0, claiming_hra: false)
      end
      expect(declaration.completeness_percent).to eq(0)
    end

    it "is 50 for a draft with some input entered" do
      declaration = ActsAsTenant.with_tenant(tenant) do
        create(:tax_declaration, :with_hra, tenant: tenant, status: :draft, landlord_pan: "ABCDE1234F")
      end
      expect(declaration.completeness_percent).to eq(50)
    end

    it "is 100 once submitted" do
      declaration = ActsAsTenant.with_tenant(tenant) { create(:tax_declaration, :submitted, tenant: tenant) }
      expect(declaration.completeness_percent).to eq(100)
    end

    it "is 100 once verified" do
      declaration = ActsAsTenant.with_tenant(tenant) { create(:tax_declaration, :verified, tenant: tenant) }
      expect(declaration.completeness_percent).to eq(100)
    end
  end
end
