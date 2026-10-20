require "rails_helper"

RSpec.describe "Employee tax declaration regime changes", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :employee) }
  let(:host) { { "Host" => "#{tenant.subdomain}.lvh.me" } }
  let!(:employee) { ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant, user: user) } }

  before do
    set_tenant(tenant)
    create(:tenant_user, tenant: tenant, user: user)
    sign_in_as(user)
  end

  def declaration
    TaxDeclaration.find_by!(employee: employee, financial_year: FinancialYear.label)
  end

  it "saves New Regime when hidden HRA and home-loan inputs are submitted" do
    patch employee_portal_tax_declaration_path, headers: host,
      params: { tax_declaration: { regime: "new_regime", claiming_hra: "1",
        monthly_rent: "12000", landlord_pan: "", home_loan_interest: "100000",
        home_loan_principal: "50000" } }

    expect(response).to redirect_to(employee_portal_tax_declaration_path)
    expect(declaration).to have_attributes(regime: "new_regime", claiming_hra: false,
      home_loan_interest: 0, home_loan_principal: 0)
    expect(declaration).to be_status_draft
  end

  it "clears incompatible claims already saved in an Old Regime draft" do
    create(:tax_declaration, tenant: tenant, employee: employee,
      financial_year: FinancialYear.label, regime: :old_regime, claiming_hra: true,
      monthly_rent: 5000, home_loan_interest: 100000, home_loan_principal: 50000)

    patch employee_portal_tax_declaration_path, headers: host,
      params: { tax_declaration: { regime: "new_regime" } }

    expect(response).to redirect_to(employee_portal_tax_declaration_path)
    expect(declaration).to have_attributes(regime: "new_regime", claiming_hra: false,
      home_loan_interest: 0, home_loan_principal: 0)
  end

  it "still validates HRA claims under Old Regime" do
    patch employee_portal_tax_declaration_path, headers: host,
      params: { tax_declaration: { regime: "old_regime", claiming_hra: "1",
        monthly_rent: "12000", landlord_pan: "" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("is required when annual rent exceeds")
    expect(declaration).to be_regime_new_regime
  end

  it "retains valid Old Regime claims" do
    patch employee_portal_tax_declaration_path, headers: host,
      params: { tax_declaration: { regime: "old_regime", claiming_hra: "1",
        monthly_rent: "5000", home_loan_interest: "100000", home_loan_principal: "50000" } }

    expect(response).to redirect_to(employee_portal_tax_declaration_path)
    expect(declaration).to have_attributes(regime: "old_regime", claiming_hra: true,
      home_loan_interest: 100000, home_loan_principal: 50000)
  end

  it "does not let a regime change edit a submitted declaration" do
    saved = create(:tax_declaration, tenant: tenant, employee: employee,
      financial_year: FinancialYear.label, regime: :old_regime, status: :submitted,
      claiming_hra: true, monthly_rent: 5000, home_loan_interest: 100000)

    patch employee_portal_tax_declaration_path, headers: host,
      params: { tax_declaration: { regime: "new_regime" } }

    expect(response).to have_http_status(:redirect)
    expect(saved.reload).to have_attributes(regime: "old_regime", claiming_hra: true,
      home_loan_interest: 100000, status: "submitted")
  end

  it "ignores invalid hidden rental and investment inputs under New Regime" do
    patch employee_portal_tax_declaration_path, headers: host,
      params: { tax_declaration: { regime: "new_regime", monthly_rent: "-100",
        investment_declarations_attributes: { "0" => { section: "80C", declared_amount: "-500" } } } }

    expect(response).to redirect_to(employee_portal_tax_declaration_path)
    expect(declaration.investment_declarations).to be_empty
  end

  it "disables hidden Old Regime fields in the rendered New Regime form" do
    get edit_employee_portal_tax_declaration_path, headers: host

    expect(response).to have_http_status(:ok)
    section = Nokogiri::HTML(response.body).at_css("fieldset[data-tax-declaration-target='regimeSection']")
    expect(section).to be_present
    expect(section.key?("disabled")).to be(true)
  end
end
