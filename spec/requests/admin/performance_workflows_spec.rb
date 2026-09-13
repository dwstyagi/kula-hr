require "rails_helper"

RSpec.describe "Bounded admin pages and background status", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :super_admin) }
  let(:headers) { { "Host" => "#{tenant.subdomain}.lvh.me" } }

  before do
    set_tenant(tenant)
    create(:tenant_user, tenant: tenant, user: user)
    create(:payroll_setting, tenant: tenant)
    sign_in_as(user)
  end

  def employees(count)
    count.times.map { |i| create(:employee, tenant: tenant, first_name: "Person#{i.to_s.rjust(3, '0')}", last_name: "Review") }
  end

  it "paginates attendance without restricting the month-wide locked check" do
    staff = employees(51)
    staff.each_with_index { |employee, i| create(:attendance_summary, tenant: tenant, employee: employee, month: 4, year: 2026, status: i == 50 ? :draft : :locked) }
    get admin_attendance_summaries_path(month: 4, year: 2026), headers: headers
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(50)
    expect(response.body).to include("Lock Month")
    expect(response.body).not_to include("Person050")
    get admin_attendance_summaries_path(month: 4, year: 2026, page: 2), headers: headers
    expect(response.body).to include("Person050")
    expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(1)
  end

  it "paginates the leave calendar" do
    employees(51)
    get admin_leave_calendar_path(month: 4, year: 2026), headers: headers
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(50)
    get admin_leave_calendar_path(month: 4, year: 2026, page: 2), headers: headers
    expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(1)
  end

  it "paginates off-cycle history" do
    26.times { |i| create(:payroll_run, tenant: tenant, initiated_by: user, run_type: "bonus", title: "Bonus #{i}", payment_date: Date.new(2026, 4, 1)) }
    get admin_off_cycle_payroll_runs_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(25)
  end

  it "shows operation status and permits retry after failure" do
    task = BackgroundTask.enqueue!(tenant: tenant, user: user, kind: "attendance", task_key: "2026-4", payload: { month: 4, year: 2026 })
    get admin_background_task_path(task), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("queued or running")
    task.update!(status: "failed")
    get admin_background_task_path(task), headers: headers
    expect(response.body).to include("Retry")
    post retry_task_admin_background_task_path(task), headers: headers
    expect(task.reload.status).to eq("queued")
  end

  it "does not expose another tenant's operation" do
    other = create(:tenant, :active)
    task = ActsAsTenant.with_tenant(other) do
      BackgroundTask.create!(tenant: other, user: user, kind: "attendance", task_key: "2026-4")
    end
    get admin_background_task_path(task), headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "renders YTD pagination with totals over the whole year and streams every export row" do
    run = create(:payroll_run, :approved, tenant: tenant, initiated_by: user, month: 4, year: 2026)
    employees(51).each { |employee| create(:payslip, tenant: tenant, payroll_run: run, employee: employee, month: 4, year: 2026) }
    get ytd_earnings_admin_reports_path(financial_year: "2026-27"), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Page 1 of 2")
    expect(response.body).not_to include("Person050")
    get download_ytd_csv_admin_reports_path(financial_year: "2026-27"), headers: headers
    expect(response).to have_http_status(:ok)
    expect(CSV.parse(response.body, headers: true).size).to eq(51)
    expect(response.body).to include("Person050")
  end
end
