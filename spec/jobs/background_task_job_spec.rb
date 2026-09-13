require "rails_helper"

RSpec.describe BackgroundTaskJob do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :hr_admin) }
  before { set_tenant(tenant); create(:payroll_setting, tenant: tenant) }

  def attendance_task
    BackgroundTask.enqueue!(tenant: tenant, user: user, kind: "attendance", task_key: "2026-4", payload: { month: 4, year: 2026 })
  end

  it "deduplicates pending requests and duplicate job deliveries" do
    create(:employee, tenant: tenant)
    task = attendance_task
    expect(attendance_task.id).to eq(task.id)
    described_class.perform_now(task.id)
    expect(task.reload.status).to eq("completed")
    expect { described_class.perform_now(task.id) }.not_to change { AttendanceSummary.first.updated_at }
  end

  it "rolls back partial work on failure and supports retry" do
    employee = create(:employee, tenant: tenant)
    task = attendance_task
    generator = instance_double(Attendance::SummaryGenerator)
    allow(Attendance::SummaryGenerator).to receive(:new).and_return(generator)
    allow(generator).to receive(:call) do
      create(:attendance_summary, employee: employee, tenant: tenant, month: 4, year: 2026)
      raise "simulated failure"
    end
    described_class.perform_now(task.id)
    expect(task.reload.status).to eq("failed")
    expect(AttendanceSummary.count).to eq(0)
    allow(Attendance::SummaryGenerator).to receive(:new).and_call_original
    task.update!(status: "queued")
    described_class.perform_now(task.id)
    expect(task.reload.status).to eq("completed")
    expect(AttendanceSummary.count).to eq(1)
  end

  it "keeps jobs within their tenant even with another current tenant" do
    employee = create(:employee, tenant: tenant)
    task = attendance_task
    other = create(:tenant, :active)
    ActsAsTenant.with_tenant(other) do
      create(:employee, tenant: other)
    end
    ActsAsTenant.with_tenant(other) { described_class.perform_now(task.id) }
    expect(task.reload.status).to eq("completed")
    expect(AttendanceSummary.pluck(:employee_id)).to eq([ employee.id ])
    expect(AttendanceSummary.unscoped.where(tenant_id: other.id)).to be_empty
  end
end
