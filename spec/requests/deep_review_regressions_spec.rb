require "rails_helper"

RSpec.describe "Deep main review reproductions", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:admin) { create(:user, :super_admin) }
  before do
    travel_to Time.zone.local(2026, 10, 18, 12)
    set_tenant(tenant)
    create(:tenant_user, tenant: tenant, user: admin)
  end
  after { travel_back }
  def host = { "Host" => "#{tenant.subdomain}.lvh.me" }
  def run_for(month: 10, year: 2026, status: "approved")
    create(:payroll_run, tenant: tenant, initiated_by: admin, month: month, year: year, status: status)
  end
  def slip_for(employee:, run:, **attrs)
    create(:payslip, tenant: tenant, employee: employee, payroll_run: run,
      month: run.month, year: run.year, **attrs)
  end

  it "limits payroll review email recipients to the payroll tenant" do
    other = create(:tenant, :active)
    outsider = create(:user, :super_admin)
    create(:tenant_user, tenant: other, user: outsider)
    run = run_for(status: "under_review")
    expect(PayrollMailer.submitted_for_review(run).message.to).to contain_exactly(admin.email)
  end

  it "keeps password reset links on the user's tenant subdomain" do
    mail = KulaDeviseMailer.reset_password_instructions(admin, "review-token").message
    expect(mail.body.encoded).to include("#{tenant.subdomain}.lvh.me/users/password/edit")
  end

  it "renders the leave encashment approval email" do
    travel_to Time.zone.local(2027, 3, 1, 12)
    employee = create(:employee, tenant: tenant)
    type = create(:leave_type, :earned, tenant: tenant)
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: type)
    request = create(:leave_encashment_request, :approved, tenant: tenant, employee: employee, leave_type: type)
    expect { LeaveMailer.encashment_approved(request).message }.not_to raise_error
  end

  it "does not remove a newer comp-off credit after an older credit was already used" do
    employee = create(:employee, tenant: tenant)
    type = create(:leave_type, tenant: tenant, code: "CO", annual_quota: 0)
    create(:comp_off_request, :approved, tenant: tenant, employee: employee,
      worked_date: Date.new(2026, 10, 4), expiry_date: Date.new(2026, 10, 16), remaining_days: 0)
    create(:comp_off_request, :approved, tenant: tenant, employee: employee,
      worked_date: Date.new(2026, 10, 11), expiry_date: Date.new(2026, 10, 24))
    balance = create(:leave_balance, tenant: tenant, employee: employee, leave_type: type,
      total_days: 2, used_days: 1, remaining_days: 1)
    Leave::CompOffExpiryJob.perform_now
    expect(balance.reload.remaining_days).to eq(1)
  end

  it "reserves days approved for encashment so they cannot also be used as paid leave" do
    travel_to Time.zone.local(2027, 3, 1, 12)
    employee = create(:employee, tenant: tenant)
    type = create(:leave_type, :earned, tenant: tenant)
    balance = create(:leave_balance, tenant: tenant, employee: employee, leave_type: type,
      total_days: 5, used_days: 0, remaining_days: 5)
    create(:leave_encashment_request, :approved, tenant: tenant, employee: employee,
      leave_type: type, number_of_days: 5)
    leave = build(:leave_request, tenant: tenant, employee: employee, leave_type: type,
      from_date: Date.new(2027, 3, 2), to_date: Date.new(2027, 3, 8))
    expect(balance.reload.remaining_days).to eq(0)
    expect(leave).not_to be_valid
  end

  it "does not turn deleted-location holidays into company-wide holidays" do
    location = create(:work_location, tenant: tenant)
    holiday = create(:holiday, tenant: tenant, work_location: location, date: Date.new(2026, 10, 19))
    expect(location.destroy).to eq(false)
    expect(holiday.reload.work_location_id).to eq(location.id)
  end

  it "includes employees without a department in the payroll breakdown total" do
    run = run_for
    employee = create(:employee, tenant: tenant, department: nil)
    slip_for(employee: employee, run: run)
    report = Reports::DepartmentBreakdownService.new(month: 10, year: 2026).call
    expect(report.summary[:total_gross]).to eq(50_000)
  end

  it "includes employer admin and EDLI charges in department CTC" do
    run = run_for
    employee = create(:employee, tenant: tenant, department: create(:department, tenant: tenant))
    slip = slip_for(employee: employee, run: run, employer_pf_admin: 75, employer_edli: 75)
    report = Reports::DepartmentBreakdownService.new(month: 10, year: 2026).call
    expect(report.summary[:total_ctc]).to eq(slip.ctc_this_month)
  end

  it "preserves paise in HDFC payments" do
    create(:payroll_setting, tenant: tenant, hdfc_corporate_code: "ACME123", salary_debit_account: "9988776655")
    run = run_for
    employee = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234")
    slip_for(employee: employee, run: run, net_pay: 45000.75)
    content = Payroll::BankFileGenerators::Hdfc.new(payroll_run: run).call
    expect(content.split("\r\n").last.split("~")[5]).to eq("45000.75")
  end

  it "lets a super admin configure the HDFC payment account before exporting" do
    setting = create(:payroll_setting, tenant: tenant)
    run = run_for
    employee = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234")
    slip_for(employee: employee, run: run)
    sign_in_as(admin)
    get edit_admin_payroll_setting_path, headers: host
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Corporate Code", "Salary Debit Account")
    patch admin_payroll_setting_path, params: { payroll_setting: {
      hdfc_corporate_code: "COMPANY123", salary_debit_account: "9988776655"
    } }, headers: host
    expect(setting.reload.salary_debit_account).to eq("9988776655")
    get download_bank_file_admin_payroll_run_path(run, bank: "hdfc"), headers: host
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("COMPANY123", "9988776655")
  end

  it "uses the employee ESI insurance number in the ESI export" do
    create(:payroll_setting, tenant: tenant)
    run = run_for
    employee = create(:employee, tenant: tenant, esi_number: "1234567890")
    slip = slip_for(employee: employee, run: run)
    create(:payslip_line_item, payslip: slip, component_name: "ESI", component_type: "deduction", amount: 150)
    report = Reports::EsiMonthlyReportService.new(month: 10, year: 2026).call
    expect(report.rows.first.ip_number).to eq(employee.esi_number)
  end

  it "allows a lost background task to be retried after dispatch exhaustion" do
    task = BackgroundTask.enqueue!(tenant: tenant, user: admin, kind: "attendance",
      task_key: "review", payload: { month: 10, year: 2026 })
    dispatch = JobDispatch.find_by!(job_class: "BackgroundTaskJob")
    dispatch.update_columns(attempts: 5, dispatched_at: 10.minutes.ago)
    dispatch.deliver
    expect(task.reload.status).to eq("failed")
  end

  it "preserves employee portal membership when HR admin access is revoked" do
    hr = create(:user, :hr_admin)
    hr.add_role(:employee)
    create(:tenant_user, tenant: tenant, user: hr)
    create(:employee, tenant: tenant, user: hr)
    sign_in_as(admin)
    delete admin_admin_user_path(hr), headers: host
    expect(hr.reload.member_of?(tenant)).to eq(true)
  end

  it "debits leave from the financial year containing the leave dates" do
    travel_to Time.zone.local(2027, 3, 20, 12)
    employee = create(:employee, tenant: tenant)
    type = create(:leave_type, tenant: tenant)
    old = create(:leave_balance, tenant: tenant, employee: employee, leave_type: type, financial_year: "2026-27")
    upcoming = create(:leave_balance, tenant: tenant, employee: employee, leave_type: type, financial_year: "2027-28")
    leave = create(:leave_request, tenant: tenant, employee: employee, leave_type: type,
      from_date: Date.new(2027, 4, 1), to_date: Date.new(2027, 4, 1))
    Leave::LeaveBalanceAdjuster.new(leave_request: leave).debit!
    expect([ old.reload.used_days, upcoming.reload.used_days ]).to eq([ 0, 1 ])
  end

  it "rejects negative attendance instead of saving invalid payable-day inputs" do
    employee = create(:employee, tenant: tenant)
    summary = create(:attendance_summary, tenant: tenant, employee: employee, month: 10, year: 2026,
      total_working_days: 22, days_present: 22)
    sign_in_as(admin)
    patch admin_attendance_summary_path(summary), params: { attendance_summary: { days_present: -10 } }, headers: host
    expect(summary.reload.days_present).to eq(22)
  end

  it "does not mix unapproved payroll into an approved payslip's YTD figures" do
    employee = create(:employee, tenant: tenant)
    older = run_for(month: 9, status: "processed")
    current = run_for(month: 10)
    slip_for(employee: employee, run: older, gross_pay: 30_000)
    slip_for(employee: employee, run: current, gross_pay: 50_000)
    expect(Payroll::PayslipPdfData.ytd(employee_ids: [ employee.id ], month: 10, year: 2026)[employee.id][:gross]).to eq(50_000)
  end

  it "updates displayed tax declaration investment totals when investments change" do
    employee = create(:employee, tenant: tenant)
    declaration = create(:tax_declaration, :old_regime, tenant: tenant, employee: employee, financial_year: "2026-27")
    declaration.update!(investment_declarations_attributes: [ { section: "80C", description: "PPF", declared_amount: 50_000 } ])
    expect(declaration.reload.total_declared_investments).to eq(50_000)
  end

  it "allocates a newly introduced paid leave type to existing employees" do
    employee = create(:employee, tenant: tenant)
    type = create(:leave_type, tenant: tenant)
    Leave::MonthlyLeaveAccrualService.new(tenant: tenant, period: Date.new(2026, 11, 1)).call
    expect(LeaveBalance.find_by(employee: employee, leave_type: type, financial_year: "2026-27")).to be_present
  end

  it "allocates paid leave immediately when HR activates a new type" do
    employee = create(:employee, tenant: tenant)
    sign_in_as(admin)
    post admin_leave_types_path, params: { leave_type: {
      name: "Personal Leave", code: "PL", annual_quota: 12, is_paid: true, is_active: false
    } }, headers: host
    type = LeaveType.find_by!(code: "PL")
    expect(LeaveBalance.find_by(employee: employee, leave_type: type)).to be_nil
    patch toggle_active_admin_leave_type_path(type), headers: host
    expect(LeaveBalance.find_by!(employee: employee, leave_type: type).remaining_days).to eq(1)
  end

  it "handles deleting an employee with payroll history without a server exception" do
    run = run_for
    employee = create(:employee, tenant: tenant)
    slip_for(employee: employee, run: run)
    sign_in_as(admin)
    expect { delete admin_employee_path(employee), headers: host }.not_to raise_error
  end

  it "allows an employee in probation with allocated balance to request leave" do
    employee = create(:employee, :probation, tenant: tenant)
    type = create(:leave_type, tenant: tenant)
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: type)
    request = build(:leave_request, tenant: tenant, employee: employee, leave_type: type,
      from_date: Date.new(2026, 10, 19), to_date: Date.new(2026, 10, 19))
    expect(request.valid?).to eq(true), request.errors.full_messages.join(", ")
  end

  it "includes the current taxable encashment in the final month's TDS computation" do
    travel_to Time.zone.local(2027, 3, 1, 12)
    create(:payroll_setting, tenant: tenant, pf_enabled: false, esi_enabled: false, pt_enabled: false, tds_enabled: true)
    run = run_for(month: 3, year: 2027, status: "processing")
    employee = create(:employee, tenant: tenant)
    structure = create(:salary_structure, tenant: tenant)
    basic = create(:salary_component, tenant: tenant, name: "Basic", calculation_type: "percentage")
    create(:salary_structure_component, salary_structure: structure, salary_component: basic, value: 100)
    create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure,
      annual_ctc: 600_000, effective_from: Date.new(2026, 4, 1))
    create(:attendance_summary, tenant: tenant, employee: employee, month: 3, year: 2027,
      status: :locked, total_working_days: 22, days_present: 22)
    type = create(:leave_type, :earned, tenant: tenant)
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: type)
    create(:leave_encashment_request, :approved, tenant: tenant, employee: employee,
      leave_type: type, number_of_days: 5, encashment_amount: 2_000_000)
    Payroll::PayrollProcessor.new(payroll_run: run).call
    slip = run.payslips.first!
    expect(slip.gross_pay).to eq(2_050_000)
    expect(slip.line_items.where(component_name: "TDS", component_type: "deduction").sum(:amount)).to be > 0
  end

  it "does not offer a payment file containing placeholder corporate account values" do
    run = run_for
    employee = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234")
    slip_for(employee: employee, run: run)
    expect { Payroll::BankFileGenerators::Hdfc.new(payroll_run: run).call }
      .to raise_error(Payroll::BankFileGenerators::BankFileError, /Configure/)
  end

  it "keeps the trial's approved payroll bank download available" do
    tenant.update!(status: "trial")
    run = run_for
    sign_in_as(admin)
    get download_bank_file_admin_payroll_run_path(run), headers: host
    expect(response).to have_http_status(:ok)
  end

  it "falls back to HR when the reporting manager's portal account is disabled" do
    manager_user = create(:user, :employee, account_active: false)
    manager = create(:employee, tenant: tenant, user: manager_user)
    employee = create(:employee, tenant: tenant, reporting_manager: manager, leave_approver: :reporting_manager)
    expect(employee.hr_is_approver?).to eq(true)
  end

  it "blocks bank payment export before payroll approval" do
    run = run_for(status: "processed")
    employee = create(:employee, tenant: tenant, bank_account_number: "1234567890", ifsc_code: "HDFC0001234")
    slip_for(employee: employee, run: run)
    sign_in_as(admin)
    get download_bank_file_admin_payroll_run_path(run), headers: host
    expect(response).not_to have_http_status(:ok)
  end

  it "does not debit expired comp-off twice after a failure updating its marker" do
    employee = create(:employee, tenant: tenant)
    type = create(:leave_type, tenant: tenant, code: "CO", annual_quota: 0)
    create(:comp_off_request, :approved, tenant: tenant, employee: employee,
      worked_date: Date.new(2026, 10, 4), expiry_date: Date.new(2026, 10, 16))
    balance = create(:leave_balance, tenant: tenant, employee: employee, leave_type: type,
      total_days: 3, used_days: 0, remaining_days: 3)
    failed_once = false
    allow_any_instance_of(CompOffRequest).to receive(:update!).and_wrap_original do |original, **attrs|
      if attrs[:balance_expired] && !failed_once
        failed_once = true
        raise "simulated marker update failure"
      end
      original.call(**attrs)
    end
    2.times { Leave::CompOffExpiryJob.perform_now }
    expect(balance.reload.remaining_days).to eq(2)
  end
end
