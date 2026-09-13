require "rails_helper"

RSpec.describe "EmployeePortal::Payslips", type: :request do
  let(:tenant)          { create(:tenant, :active) }
  let(:emp_user)        { create(:user, :employee) }
  let(:employee)        { create(:employee, tenant: tenant, user: emp_user) }
  let(:subdomain_host)  { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: emp_user) }
    set_tenant(tenant)
    employee
    sign_in_as(emp_user)
  end

  def headers = { "Host" => subdomain_host }

  def create_payslip(month:, year:, gross_pay: 50_000, total_deductions: 5_000, net_pay: 45_000)
    ActsAsTenant.with_tenant(tenant) do
      run = create(:payroll_run, :approved, tenant: tenant, month: month, year: year)
      create(:payslip, tenant: tenant, payroll_run: run, employee: employee,
             month: month, year: year,
             gross_pay: gross_pay, total_deductions: total_deductions, net_pay: net_pay)
    end
  end

  describe "GET /portal/payslips" do
    it "returns 200 and lists the employee's payslips" do
      payslip = create_payslip(month: 8, year: 2026)
      get employee_portal_payslips_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.text).to include(payslip.period_label)
    end

    it "shows the empty state when there are no payslips" do
      get employee_portal_payslips_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.text).to include("No payslips available yet")
    end

    it "only shows the most recent 24 payslips" do
      # 26 months, oldest first: Apr 2024 .. May 2026 (current date is 2026-09-13)
      (0..25).each do |i|
        date = Date.new(2024, 4, 1) + i.months
        create_payslip(month: date.month, year: date.year)
      end

      get employee_portal_payslips_path, headers: headers
      expect(response).to have_http_status(:ok)

      oldest_label = Payslip.new(month: 4, year: 2024).period_label
      newest_label = Payslip.new(month: 5, year: 2026).period_label

      expect(response.parsed_body.text).not_to include(oldest_label)
      expect(response.parsed_body.text).to include(newest_label)
    end

    it "computes the YTD summary only from payslips in the current financial year" do
      # Current FY (2026-09-13 falls in FY 2026-27, which starts April 2026)
      create_payslip(month: 4, year: 2026, gross_pay: 60_000, total_deductions: 6_000, net_pay: 54_000)
      create_payslip(month: 8, year: 2026, gross_pay: 40_000, total_deductions: 4_000, net_pay: 36_000)
      # Previous FY — must be excluded from YTD totals
      create_payslip(month: 2, year: 2026, gross_pay: 1_000_000, total_deductions: 100_000, net_pay: 900_000)

      get employee_portal_payslips_path, headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body.text
      expect(body).to include("₹100,000") # YTD gross: 60,000 + 40,000
      expect(body).to include("₹90,000")  # YTD net: 54,000 + 36,000
      expect(body).not_to include("₹1,100,000") # would only appear if the earlier FY leaked in
    end
  end
end
