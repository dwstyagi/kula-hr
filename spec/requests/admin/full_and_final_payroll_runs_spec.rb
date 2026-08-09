require "rails_helper"

RSpec.describe "Admin::FullAndFinalPayrollRuns", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:employee) { create(:employee, tenant: tenant, joining_date: Date.new(2025, 1, 1)) }
  let(:host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: hr_user)
    end
    set_tenant(tenant)
    sign_in_as(hr_user)
  end

  def headers = { "Host" => host }

  it "renders the employee selector and settlement preview" do
    get new_admin_full_and_final_payroll_run_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("New Full &amp; Final Settlement")

    get new_admin_full_and_final_payroll_run_path,
      params: { employee_id: employee.id, last_working_date: "2026-08-15" },
      headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Earnings")
    expect(response.body).to include(employee.full_name)
  end

  it "creates a draft F&F run without locked attendance" do
    expect do
      post admin_full_and_final_payroll_runs_path,
        params: {
          payroll_run: {
            title: "Full & Final - #{employee.full_name}",
            payment_date: "2026-08-31",
            full_and_final_settlement_attributes: {
              employee_id: employee.id,
              last_working_date: "2026-08-15",
              salary_days: "15",
              earned_salary: "30000",
              leave_encashment_days: "5",
              leave_encashment: "4000",
              notice_recovery: "5000",
              tds_amount: "2000"
            }
          }
        },
        headers: headers
    end.to change { PayrollRun.where(run_type: "full_and_final").count }.by(1)

    run = PayrollRun.where(run_type: "full_and_final").last
    expect(run.month).to eq(8)
    expect(run.full_and_final_settlement.net_pay).to eq(27_000)
    expect(response).to redirect_to(admin_off_cycle_payroll_run_path(run))
  end

  it "allows settlement corrections while draft" do
    settlement = create(:full_and_final_settlement, tenant: tenant)
    run = settlement.payroll_run

    patch admin_off_cycle_payroll_run_path(run),
      params: {
        payroll_run: {
          title: run.title,
          payment_date: "2026-09-01",
          full_and_final_settlement_attributes: {
            id: settlement.id,
            employee_id: settlement.employee_id,
            last_working_date: settlement.last_working_date,
            earned_salary: "35000",
            leave_encashment: "5000"
          }
        }
      },
      headers: headers

    expect(response).to redirect_to(admin_off_cycle_payroll_run_path(run))
    expect(settlement.reload.earned_salary).to eq(35_000)
    expect(run.reload).to be_full_and_final
  end
end
