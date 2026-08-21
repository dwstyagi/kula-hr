require "rails_helper"

RSpec.describe "Admin::OffCyclePayrollRuns", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:hr_user) { create(:user, :hr_admin) }
  let(:admin) { create(:user, :super_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: hr_user)
      create(:tenant_user, tenant: tenant, user: admin)
    end
    set_tenant(tenant)
  end

  def headers = { "Host" => host }

  def create_run(initiated_by: hr_user, status: "draft")
    PayrollRun.create!(
      tenant: tenant,
      initiated_by: initiated_by,
      run_type: "bonus",
      title: "Annual Bonus",
      payment_date: Date.new(2026, 8, 15),
      month: 8,
      year: 2026,
      status: status,
      off_cycle_payroll_entries_attributes: [
        { tenant: tenant, employee: employee, gross_amount: 25_000, tds_amount: 2_500 }
      ]
    )
  end

  it "renders the list, creation form, draft, and edit pages" do
    run = create_run
    sign_in_as(hr_user)

    get admin_off_cycle_payroll_runs_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Annual Bonus")

    get new_admin_off_cycle_payroll_run_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Employees and amounts")

    get admin_off_cycle_payroll_run_path(run), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment inputs")

    get edit_admin_off_cycle_payroll_run_path(run), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Edit off-cycle inputs")
  end

  it "creates a bonus run without locked attendance" do
    sign_in_as(hr_user)

    expect do
      post admin_off_cycle_payroll_runs_path,
        params: {
          payroll_run: {
            run_type: "bonus", title: "Festival Bonus", payment_date: "2026-08-20",
            off_cycle_payroll_entries_attributes: {
              "0" => { employee_id: employee.id, gross_amount: "30000", tds_amount: "3000" }
            }
          }
        },
        headers: headers
    end.to change { PayrollRun.off_cycle.count }.by(1)

    run = PayrollRun.off_cycle.last
    expect(run.month).to eq(8)
    expect(run.off_cycle_payroll_entries.first.net_amount).to eq(27_000)
    expect(response).to redirect_to(admin_off_cycle_payroll_run_path(run))
  end

  it "allows multiple off-cycle runs in the same month" do
    create_run
    sign_in_as(hr_user)

    expect do
      post admin_off_cycle_payroll_runs_path,
        params: {
          payroll_run: {
            run_type: "additional", title: "Spot Award", payment_date: "2026-08-25",
            off_cycle_payroll_entries_attributes: {
              "0" => { employee_id: employee.id, gross_amount: "5000", tds_amount: "0" }
            }
          }
        },
        headers: headers
    end.to change { PayrollRun.off_cycle.count }.by(1)
  end

  it "enqueues processing" do
    run = create_run
    sign_in_as(hr_user)
    expect(PayrollProcessingJob).to receive(:perform_later).with(run.id)
    post process_payroll_admin_off_cycle_payroll_run_path(run), headers: headers
    expect(run.reload).to be_processing
  end

  it "updates employee amounts while the run is in draft" do
    run = create_run
    entry = run.off_cycle_payroll_entries.first
    sign_in_as(hr_user)
    patch admin_off_cycle_payroll_run_path(run),
      params: {
        payroll_run: {
          title: "Revised Bonus", run_type: "bonus", payment_date: "2026-08-16",
          off_cycle_payroll_entries_attributes: {
            "0" => { id: entry.id, employee_id: employee.id, gross_amount: "40000", tds_amount: "5000" }
          }
        }
      },
      headers: headers

    expect(response).to redirect_to(admin_off_cycle_payroll_run_path(run))
    expect(entry.reload.net_amount).to eq(35_000)
  end

  it "does not allow input edits after processing" do
    run = create_run(status: "processed")
    sign_in_as(hr_user)
    get edit_admin_off_cycle_payroll_run_path(run), headers: headers
    expect(response).to redirect_to(admin_off_cycle_payroll_run_path(run))
  end

  it "prevents the creator from approving their own off-cycle run" do
    run = create_run(initiated_by: admin, status: "under_review")
    sign_in_as(admin)
    patch approve_admin_off_cycle_payroll_run_path(run), headers: headers
    expect(run.reload).to be_under_review
  end

  it "lets the creator reject their own off-cycle run so it is never stranded" do
    run = create_run(initiated_by: admin, status: "under_review")
    sign_in_as(admin)

    patch reject_admin_off_cycle_payroll_run_path(run),
          params: { rejection_reason: "Raised against the wrong cost centre" }, headers: headers

    expect(run.reload).to be_rejected
    expect(run.rejection_reason).to eq("Raised against the wrong cost centre")
  end

  it "refuses to send a run with no payslips for review" do
    run = create_run(status: "processed")
    sign_in_as(hr_user)

    patch submit_for_review_admin_off_cycle_payroll_run_path(run), headers: headers

    expect(run.reload).to be_processed
    expect(flash[:alert]).to match(/no payslips/)
  end

  it "lets a different super admin approve and lock the payslip" do
    run = create_run(status: "under_review")
    payslip = create(:payslip, tenant: tenant, payroll_run: run, employee: employee)
    sign_in_as(admin)
    patch approve_admin_off_cycle_payroll_run_path(run), headers: headers
    expect(run.reload).to be_approved
    expect(payslip.reload).to be_locked
  end

  it "closes the employee out of payroll when a settlement is approved" do
    run = nil
    ActsAsTenant.with_tenant(tenant) do
      settlement = create(:full_and_final_settlement, tenant: tenant, employee: employee)
      run = settlement.payroll_run
      run.update_columns(initiated_by_id: hr_user.id, status: "under_review")
      create(:payslip, tenant: tenant, payroll_run: run, employee: employee)
    end
    sign_in_as(admin)

    patch approve_admin_off_cycle_payroll_run_path(run), headers: headers

    expect(run.reload).to be_approved
    expect(employee.reload.employment_status).to eq("resigned")
    expect(employee.last_working_date).to eq(Date.new(2026, 8, 15))
  end

  it "renders bank formats in a dropdown for approved runs" do
    run = create_run(status: "approved")
    sign_in_as(hr_user)

    get bank_file_admin_off_cycle_payroll_run_path(run), headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="bank"')
    expect(response.body).to include("Generic CSV (.csv)", "State Bank of India (.txt)")
    expect(response.body).not_to include('type="radio"')
  end
end
