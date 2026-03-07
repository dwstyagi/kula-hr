require "rails_helper"

RSpec.describe "Admin::Reports", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:host) { "#{tenant.subdomain}.lvh.me" }
  let(:headers) { { "Host" => host } }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: hr_user)
    end
    set_tenant(tenant)
    sign_in_as(hr_user)
  end

  describe "GET /admin/reports" do
    it "renders the reports hub" do
      get admin_reports_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Reports")
    end
  end

  describe "GET /admin/reports/department_breakdown" do
    it "renders department breakdown" do
      get department_breakdown_admin_reports_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Department Breakdown")
    end

    it "accepts month/year params" do
      get department_breakdown_admin_reports_path(month: 1, year: 2026), headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/reports/download_department_csv" do
    it "returns CSV" do
      get download_department_csv_admin_reports_path(month: 1, year: 2026), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end
  end

  describe "GET /admin/reports/pf_report" do
    it "renders PF report" do
      get pf_report_admin_reports_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PF Monthly Report")
    end
  end

  describe "GET /admin/reports/download_pf_ecr" do
    it "returns ECR text file" do
      get download_pf_ecr_admin_reports_path(month: 1, year: 2026), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/plain")
    end
  end

  describe "GET /admin/reports/esi_report" do
    it "renders ESI report" do
      get esi_report_admin_reports_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ESI Monthly Report")
    end
  end

  describe "GET /admin/reports/download_esi_csv" do
    it "returns CSV" do
      get download_esi_csv_admin_reports_path(month: 1, year: 2026), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end
  end

  describe "GET /admin/reports/pt_challan" do
    it "renders PT challan" do
      get pt_challan_admin_reports_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Professional Tax Challan")
    end
  end

  describe "GET /admin/reports/download_pt_csv" do
    it "returns CSV" do
      get download_pt_csv_admin_reports_path(month: 1, year: 2026), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end
  end

  describe "GET /admin/reports/ytd_earnings" do
    it "renders YTD earnings" do
      get ytd_earnings_admin_reports_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("YTD Earnings")
    end
  end

  describe "GET /admin/reports/download_ytd_csv" do
    it "returns CSV" do
      get download_ytd_csv_admin_reports_path(financial_year: "2025-26"), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end
  end

  describe "authorization" do
    let(:employee_user) { create(:user) }

    before do
      ActsAsTenant.with_tenant(tenant) do
        create(:tenant_user, tenant: tenant, user: employee_user)
      end
    end

    it "redirects non-admin users" do
      # Sign out HR, sign in as regular user
      delete destroy_user_session_path, headers: headers
      sign_in_as(employee_user)

      get admin_reports_path, headers: headers
      expect(response).to be_redirect
    end
  end
end
