require "rails_helper"

RSpec.describe "Admin::TaxDeclarations", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:user)     { create(:user, :hr_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:host)     { { "Host" => "#{tenant.subdomain}.lvh.me" } }
  let!(:declaration) do
    ActsAsTenant.with_tenant(tenant) do
      create(:tax_declaration, :old_regime, :submitted, tenant: tenant, employee: employee,
             financial_year: LeaveBalance.current_financial_year)
    end
  end

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  it "lists this year's declarations" do
    get admin_tax_declarations_path, headers: host
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(employee.full_name)
  end

  it "shows a declaration" do
    get admin_tax_declaration_path(declaration), headers: host
    expect(response).to have_http_status(:ok)
  end

  it "verifies a submitted declaration" do
    patch verify_admin_tax_declaration_path(declaration), headers: host
    expect(declaration.reload).to be_status_verified
  end

  it "returns a declaration to draft so the employee can edit it" do
    patch return_to_draft_admin_tax_declaration_path(declaration), params: { note: "Add rent receipts" }, headers: host
    expect(declaration.reload).to be_status_draft
  end

  it "does not verify a draft" do
    declaration.update!(status: :draft)
    patch verify_admin_tax_declaration_path(declaration), headers: host
    expect(response).to be_redirect
    expect(declaration.reload).to be_status_draft
  end
end
