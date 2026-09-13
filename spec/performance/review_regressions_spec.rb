require "rails_helper"

RSpec.describe "Review regression protections" do
  let(:tenant) { create(:tenant, :active) }
  before { set_tenant(tenant) }

  it "keeps a failed queue delivery durable and recovers it once" do
    allow(BackgroundTaskJob).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "offline")
    dispatch = JobDispatch.enqueue!(BackgroundTaskJob, 123)
    dispatch.deliver
    expect(dispatch.reload.dispatched_at).to be_nil
    expect(dispatch.last_error).to include("offline")
    allow(BackgroundTaskJob).to receive(:perform_later).and_call_original
    expect { JobDispatch.recover }.to have_enqueued_job(BackgroundTaskJob).with(123, dispatch_id: dispatch.id)
    expect { JobDispatch.recover }.not_to have_enqueued_job(BackgroundTaskJob)
    expect(JobDispatch.enqueue!(BackgroundTaskJob, 123).id).to eq(dispatch.id)
  end

  it "reclaims a dispatch when its worker lease expires" do
    dispatch = JobDispatch.enqueue!(BackgroundTaskJob, 123)
    dispatch.update_column(:dispatched_at, 6.minutes.ago)
    expect { JobDispatch.recover }.to have_enqueued_job(BackgroundTaskJob).with(123, dispatch_id: dispatch.id)
  end

  it "rolls back the outbox together with its originating transaction" do
    expect do
      JobDispatch.transaction(requires_new: true) do
        JobDispatch.enqueue!(BackgroundTaskJob, 456)
        raise ActiveRecord::Rollback
      end
    end.not_to have_enqueued_job(BackgroundTaskJob)
    expect(JobDispatch.where("arguments = ?::jsonb", [ 456 ].to_json)).not_to exist
  end

  it "acknowledges completed background work and removes its upload payload" do
    user = create(:user, :hr_admin)
    task = BackgroundTask.enqueue!(tenant: tenant, user: user, kind: "attendance_import", task_key: "csv",
      payload: { month: 5, year: 2026, csv: "employee_code,days_present,half_days\nunknown,1,0\n" })
    dispatch = JobDispatch.where(job_class: "BackgroundTaskJob").where("arguments = ?::jsonb", [ task.id ].to_json).first!
    BackgroundTaskJob.perform_now(task.id, dispatch_id: dispatch.id)
    expect(task.reload.status).to eq("completed")
    expect(task.payload).not_to have_key("csv")
    expect(JobDispatch.exists?(dispatch.id)).to be(false)
  end

  it "does not credit a monthly leave allocation twice" do
    employee = create(:employee, tenant: tenant, joining_date: Date.new(2025, 1, 1))
    type = create(:leave_type, :casual, tenant: tenant, annual_quota: 12)
    balance = create(:leave_balance, tenant: tenant, employee: employee, leave_type: type,
      financial_year: "2026-27", total_days: 1, remaining_days: 1)
    service = Leave::MonthlyLeaveAccrualService.new(tenant: tenant, period: Date.new(2026, 5, 1))
    2.times { service.call }
    expect(balance.reload.total_days).to eq(2)
    expect(LeaveAccrual.count).to eq(1)
  end

  it "rolls back the monthly marker if the credit fails, allowing retry" do
    create(:leave_type, :casual, tenant: tenant)
    service = Leave::MonthlyLeaveAccrualService.new(tenant: tenant, period: Date.new(2026, 5, 1))
    allow(LeaveBalance).to receive(:where).and_raise("database interruption")
    expect { service.call }.to raise_error("database interruption")
    expect(LeaveAccrual.count).to eq(0)
    allow(LeaveBalance).to receive(:where).and_call_original
    expect { service.call }.to change(LeaveAccrual, :count).by(1)
  end

  it "allocates numerically past EMP9999 and shares the sequence with bulk reservations" do
    create(:employee, tenant: tenant, employee_code: "EMP9999")
    create(:employee, tenant: tenant, employee_code: "EMP10000")
    expect(Employees::CodeAllocator.reserve(tenant, 2)).to eq(%w[EMP10001 EMP10002])
    expect(create(:employee, tenant: tenant, employee_code: nil).employee_code).to eq("EMP10003")
  end

  it "returns exact readiness counts without instantiating every employee" do
    55.times { create(:employee, tenant: tenant) }
    loaded = 0
    callback = ->(*args) { loaded += args.last[:record_count] if args.last[:class_name] == "Employee" }
    ActiveSupport::Notifications.subscribed(callback, "instantiation.active_record") do
      result = Payroll::ReadinessCheck.new(tenant: tenant, month: 5, year: 2026).call
      expect(result.eligible_count).to eq(55)
      expect(result.can_create?).to be(false)
      expect(loaded).to eq(0)
      expect(result.blocking.to_a.size).to eq(50)
    end
    expect(loaded).to eq(50)
  end

  it "writes a complete XLSX in batches that can be read by a spreadsheet reader" do
    105.times { create(:employee, tenant: tenant) }
    create(:employee, tenant: tenant, first_name: "A&B", bank_account_number: "00001234")
    loaded = []
    callback = ->(*args) { loaded << args.last[:record_count] if args.last[:class_name] == "Employee" }
    file = nil
    ActiveSupport::Notifications.subscribed(callback, "instantiation.active_record") do
      file = Employees::ExportGenerator.new(Employee.includes(:department, :designation)).file
    end
    sheet = Roo::Excelx.new(file.path)
    expect(sheet.last_row).to eq(107)
    expect(sheet.cell(107, 2)).to eq("A&B")
    expect(sheet.cell(107, 17)).to eq("00001234")
    expect(loaded.max).to be <= 100
    body = Downloads::TemporaryFile.new(file)
    path = file.path
    bytes = body.each.to_a.join
    expect(bytes).to start_with("PK")
    expect(File.exist?(path)).to be(false)
  ensure
    file&.close!
  end

  it "removes abandoned partial archives as well as expired ZIPs" do
    Dir.mktmpdir do |directory|
      allow(Payroll::PayslipArchive).to receive(:root).and_return(Pathname(directory))
      %w[old.zip old.part fresh.zip].each { |name| File.write(File.join(directory, name), "data") }
      %w[old.zip old.part].each { |name| File.utime(2.days.ago.to_time, 2.days.ago.to_time, File.join(directory, name)) }
      Payroll::PayslipArchive.cleanup
      expect(Dir.children(directory)).to eq([ "fresh.zip" ])
    end
  end
end
