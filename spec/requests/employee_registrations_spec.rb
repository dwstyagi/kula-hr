require "rails_helper"

RSpec.describe "EmployeeRegistrations", type: :request do
  let(:tenant)         { create(:tenant, :active) }
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }
  let(:token)          { "valid_token_abc" }

  before do
    tenant.update!(
      invite_token:            token,
      invite_token_expires_at: 1.hour.from_now
    )
    set_tenant(tenant)
  end

  describe "GET /join/:token (new)" do
    it "returns 200 with a valid token" do
      get employee_registration_path(token), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end

    it "renders invalid_token page when token is wrong" do
      get employee_registration_path("bad_token"), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Invalid")
    end

    it "renders invalid_token page when token is expired" do
      tenant.update!(invite_token_expires_at: 1.hour.ago)
      get employee_registration_path(token), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /join/:token (create)" do
    let(:valid_params) do
      {
        employee: {
          first_name:        "Jane",
          last_name:         "Doe",
          email:             "jane.doe@example.com",
          joining_date:      "2026-04-01",
          employment_status: "active"
        }
      }
    end

    it "creates employee + user and redirects to sent page" do
      expect {
        post employee_registration_submit_path(token),
             params: valid_params,
             headers: { "Host" => subdomain_host }
      }.to change { Employee.count }.by(1).and change { User.count }.by(1)

      expect(response).to redirect_to(employee_registration_sent_path(token))
    end

    it "shows error when email is already registered" do
      create(:user, email: "jane.doe@example.com")

      post employee_registration_submit_path(token),
           params: valid_params,
           headers: { "Host" => subdomain_host }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("already registered")
      expect(Employee.count).to eq(0)
    end

    it "shows error when tenant is at employee limit" do
      allow_any_instance_of(Tenant).to receive(:at_employee_limit?).and_return(true)

      post employee_registration_submit_path(token),
           params: valid_params,
           headers: { "Host" => subdomain_host }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("employee limit")
    end

    it "silently succeeds (honeypot) when website field is filled" do
      post employee_registration_submit_path(token),
           params: valid_params.merge(website: "http://spam.com"),
           headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(employee_registration_sent_path(token))
      expect(Employee.count).to eq(0)
    end

    it "re-renders form with validation errors for missing required fields" do
      post employee_registration_submit_path(token),
           params: { employee: { first_name: "", last_name: "", email: "" } },
           headers: { "Host" => subdomain_host }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /join/:token/sent" do
    it "returns 200" do
      get employee_registration_sent_path(token), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end
end
