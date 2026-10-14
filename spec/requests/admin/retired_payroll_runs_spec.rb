require "rails_helper"

RSpec.describe "Retired payroll runs", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :super_admin) }
  let(:headers) { { "Host" => "#{tenant.subdomain}.lvh.me" } }

  before do
    set_tenant(tenant)
    create(:tenant_user, tenant: tenant, user: user)
    sign_in_as(user)
  end

  %w[bonus additional full_and_final].each do |type|
    it "preserves #{type} history without exposing monthly payroll actions" do
      run = create(:payroll_run, :processed, tenant: tenant, initiated_by: user, run_type: type)
      payslip = create(:payslip, tenant: tenant, payroll_run: run)
      get admin_payroll_run_path(run), headers: headers
      expect(response).to have_http_status(:not_found)
      post process_payroll_admin_payroll_run_path(run), headers: headers
      expect(response).to have_http_status(:not_found)
      patch approve_admin_payroll_run_path(run), headers: headers
      expect(response).to have_http_status(:not_found)
      expect(run.reload).to be_processed
      expect(run.payslips).to include(payslip)
      expect(PayslipPolicy.new(user, payslip)).not_to be_edit
    end
  end
end
