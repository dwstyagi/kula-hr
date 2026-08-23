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

  def create_run
    post admin_full_and_final_payroll_runs_path,
      params: { payroll_run: { title: "August Exits", payment_date: "2026-08-31" } },
      headers: headers
    PayrollRun.where(run_type: "full_and_final").last
  end

  it "renders the run details form" do
    get new_admin_full_and_final_payroll_run_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("New Full &amp; Final Settlement")
  end

  it "creates an empty draft run without locked attendance" do
    expect { create_run }.to change { PayrollRun.where(run_type: "full_and_final").count }.by(1)

    run = PayrollRun.where(run_type: "full_and_final").last
    expect(run.month).to eq(8)
    expect(run.year).to eq(2026)
    expect(run.full_and_final_settlements).to be_empty
    expect(response).to redirect_to(edit_admin_off_cycle_payroll_run_path(run))
  end

  it "adds an employee with previewed amounts" do
    run = create_run

    expect do
      post add_employee_admin_full_and_final_payroll_run_path(run),
        params: { employee_id: employee.id, last_working_date: "2026-08-15" },
        headers: headers
    end.to change { run.full_and_final_settlements.count }.by(1)

    settlement = run.full_and_final_settlements.last
    expect(settlement.employee).to eq(employee)
    expect(settlement.last_working_date).to eq(Date.new(2026, 8, 15))
    expect(response).to redirect_to(edit_admin_off_cycle_payroll_run_path(run))
  end

  it "settles several employees in one run" do
    other = create(:employee, tenant: tenant, joining_date: Date.new(2025, 1, 1))
    run = create_run

    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: employee.id, last_working_date: "2026-08-05" }, headers: headers
    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: other.id, last_working_date: "2026-08-20" }, headers: headers

    expect(run.full_and_final_settlements.count).to eq(2)
    expect(run.full_and_final_settlements.map(&:last_working_date))
      .to contain_exactly(Date.new(2026, 8, 5), Date.new(2026, 8, 20))
  end

  it "refuses to add the same employee twice" do
    run = create_run
    2.times do
      post add_employee_admin_full_and_final_payroll_run_path(run),
        params: { employee_id: employee.id, last_working_date: "2026-08-15" }, headers: headers
    end

    expect(run.full_and_final_settlements.count).to eq(1)
    expect(flash[:alert]).to match(/already being settled/)
  end

  it "requires both an employee and a last working date" do
    run = create_run

    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: employee.id }, headers: headers

    expect(run.full_and_final_settlements).to be_empty
    expect(flash[:alert]).to match(/last working date/)
  end

  it "refuses to add employees once the run leaves draft" do
    run = create_run
    run.update_columns(status: "processed")

    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: employee.id, last_working_date: "2026-08-15" }, headers: headers

    expect(run.full_and_final_settlements).to be_empty
    expect(flash[:alert]).to match(/only be added while the run is in draft/)
  end

  it "allows settlement corrections while draft" do
    settlement = create(:full_and_final_settlement, tenant: tenant)
    run = settlement.payroll_run

    patch admin_off_cycle_payroll_run_path(run),
      params: {
        payroll_run: {
          title: run.title,
          payment_date: "2026-09-01",
          full_and_final_settlements_attributes: {
            "0" => {
              id: settlement.id,
              employee_id: settlement.employee_id,
              last_working_date: settlement.last_working_date,
              earned_salary: "35000",
              leave_encashment: "5000"
            }
          }
        }
      },
      headers: headers

    expect(response).to redirect_to(admin_off_cycle_payroll_run_path(run))
    expect(settlement.reload.earned_salary).to eq(35_000)
    expect(run.reload).to be_full_and_final
  end

  it "removes an employee from a draft settlement run" do
    settlement = create(:full_and_final_settlement, tenant: tenant)
    run = settlement.payroll_run

    patch admin_off_cycle_payroll_run_path(run),
      params: {
        payroll_run: {
          title: run.title, payment_date: "2026-09-01",
          full_and_final_settlements_attributes: {
            "0" => { id: settlement.id, employee_id: settlement.employee_id, _destroy: "1" }
          }
        }
      },
      headers: headers

    expect(run.reload.full_and_final_settlements).to be_empty
  end

  it "refuses to calculate a run with nobody in it" do
    run = create_run

    post process_payroll_admin_off_cycle_payroll_run_path(run), headers: headers

    expect(run.reload).to be_draft
    expect(flash[:alert]).to match(/at least one employee to settle/)
  end

  it "renders the edit page with the picker and one block per employee" do
    other = create(:employee, tenant: tenant, first_name: "Meera", last_name: "Nair")
    run = create_run
    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: employee.id, last_working_date: "2026-08-05" }, headers: headers
    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: other.id, last_working_date: "2026-08-20" }, headers: headers

    get edit_admin_off_cycle_payroll_run_path(run), headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Add an employee to settle")
    expect(response.body).to include(employee.full_name, other.full_name)
    # already-added employees drop out of the picker
    expect(response.body.scan(/full_and_final_settlements_attributes\]\[\d+\]\[employee_id\]/).size).to eq(2)
  end

  it "renders the draft summary and the empty state" do
    run = create_run

    get edit_admin_off_cycle_payroll_run_path(run), headers: headers
    expect(response.body).to include("No employees added yet")

    post add_employee_admin_full_and_final_payroll_run_path(run),
      params: { employee_id: employee.id, last_working_date: "2026-08-15" }, headers: headers

    get admin_off_cycle_payroll_run_path(run), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Settlement inputs", "1 employee")
  end
end
