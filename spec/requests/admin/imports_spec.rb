require "rails_helper"

RSpec.describe "Admin::Imports", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }

  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: user)
    end
    set_tenant(tenant)
    sign_in_as(user)
  end

  def with_host(&block)
    host! subdomain_host
    block.call
  end

  # Builds a minimal valid xlsx tempfile
  def build_valid_xlsx
    headers = Employees::TemplateGenerator::HEADERS
    tmpfile = Tempfile.new([ "import_test", ".xlsx" ])
    tmpfile.binmode

    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Sheet1") do |sheet|
      sheet.add_row headers
      sheet.add_row [
        "Jane", "Doe", "jane@example.com", "9876543210",
        "15/08/1990", "female", "01/06/2023", "active",
        "", "", "", "", "", "",
        "", "", "", "", "", "", "",
        "", "", ""
      ]
    end
    package.serialize(tmpfile.path)
    tmpfile
  end

  describe "GET /admin/imports/new" do
    it "returns 200" do
      get new_admin_import_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/imports" do
    context "with no file" do
      it "re-renders new with alert" do
        post admin_imports_path,
             params: {},
             headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with a valid xlsx file" do
      it "redirects to preview" do
        file = build_valid_xlsx
        post admin_imports_path,
             params: { file: Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") },
             headers: { "Host" => subdomain_host }
        expect(response).to redirect_to(preview_admin_imports_path)
      end
    end
  end

  describe "GET /admin/imports/preview" do
    context "with no cache key in session" do
      it "redirects to new with alert" do
        get preview_admin_imports_path, headers: { "Host" => subdomain_host }
        expect(response).to redirect_to(new_admin_import_path)
      end
    end
  end

  describe "POST /admin/imports/confirm" do
    context "with no cache key in session" do
      it "redirects to new with alert" do
        post confirm_admin_imports_path, headers: { "Host" => subdomain_host }
        expect(response).to redirect_to(new_admin_import_path)
      end
    end

    context "after a successful parse (end-to-end)", :with_cache do
      before do
        # POST creates → caches rows + sets session[:import_cache_key]
        post admin_imports_path,
             params: { file: Rack::Test::UploadedFile.new(build_valid_xlsx.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") },
             headers: { "Host" => subdomain_host }
      end

      it "imports employees and redirects to employees list" do
        expect {
          post confirm_admin_imports_path, headers: { "Host" => subdomain_host }
        }.to change { Employee.unscoped.where(tenant_id: tenant.id).count }.by_at_least(1)

        expect(response).to redirect_to(admin_employees_path)
      end
    end
  end
end
