require "rails_helper"

RSpec.describe "Admin employee creation with an existing login", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:admin)  { create(:user, :super_admin, email: "owner@acme.test") }
  let(:host)   { { "Host" => "#{tenant.subdomain}.lvh.me" } }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: admin) }
    set_tenant(tenant)
    sign_in_as(admin)
  end

  def create_employee(email)
    post admin_employees_path, headers: host, params: { employee: {
      first_name: "Asha", last_name: "Rao", email: email, joining_date: "2026-04-01", employment_status: "active"
    } }
  end

  it "links an admin's own login to their new employee record and keeps their admin role" do
    expect { create_employee("owner@acme.test") }.to change { ActsAsTenant.with_tenant(tenant) { Employee.count } }.by(1)
    employee = ActsAsTenant.with_tenant(tenant) { Employee.find_by(email: "owner@acme.test") }
    expect(employee.user).to eq(admin)
    expect(admin.reload).to have_role(:super_admin)
    expect(admin).to have_role(:employee)
  end

  it "explains when the email belongs to another company's account" do
    create(:user, email: "taken@else.test")
    create_employee("taken@else.test")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("already used by an account in another company")
  end
end
