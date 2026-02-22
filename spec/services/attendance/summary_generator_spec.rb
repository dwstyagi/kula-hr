require "rails_helper"

RSpec.describe Attendance::SummaryGenerator do
  let(:tenant)          { create(:tenant) }
  let(:payroll_setting) { create(:payroll_setting, tenant: tenant, week_off_pattern: "all_saturdays_sundays") }
  let(:employee)        { create(:employee, tenant: tenant) }
  let(:paid_type)       { create(:leave_type, :casual, tenant: tenant) }
  let(:lop_type)        { create(:leave_type, :lop,    tenant: tenant) }

  before do
    set_tenant(tenant)
    payroll_setting
    employee   # force creation so generator finds at least one active employee
  end

  subject(:generator) { described_class.new(month: 1, year: 2025, tenant: tenant) }

  describe "#call" do
    it "creates an AttendanceSummary for each active employee" do
      expect { generator.call }.to change { AttendanceSummary.count }.by(1)
    end

    it "sets total_working_days from WorkingDaysCalculator" do
      generator.call
      summary = AttendanceSummary.find_by(employee: employee, month: 1, year: 2025)
      expect(summary.total_working_days).to eq(23)   # Jan 2025, all_sat_sun
    end

    it "auto-fills approved paid leaves from leave requests" do
      # Create 2 approved paid leave days in January 2025
      lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: paid_type,
                 from_date: Date.new(2025, 1, 6), to_date: Date.new(2025, 1, 7))
      lr.save(validate: false)

      generator.call
      summary = AttendanceSummary.find_by(employee: employee, month: 1, year: 2025)
      expect(summary.approved_leaves).to eq(2)
    end

    it "auto-fills lop_leaves from approved LOP leave requests" do
      lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: lop_type,
                 from_date: Date.new(2025, 1, 8), to_date: Date.new(2025, 1, 8))
      lr.save(validate: false)

      generator.call
      summary = AttendanceSummary.find_by(employee: employee, month: 1, year: 2025)
      expect(summary.lop_leaves).to eq(1)
    end

    it "defaults days_present to working_days minus approved leaves" do
      lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: paid_type,
                 from_date: Date.new(2025, 1, 6), to_date: Date.new(2025, 1, 7))
      lr.save(validate: false)

      generator.call
      summary = AttendanceSummary.find_by(employee: employee, month: 1, year: 2025)
      expect(summary.days_present).to eq(21)   # 23 - 2
    end

    it "does not generate summaries for resigned employees" do
      resigned = create(:employee, :resigned, tenant: tenant)
      generator.call
      expect(AttendanceSummary.find_by(employee: resigned, month: 1, year: 2025)).to be_nil
    end

    it "does not overwrite locked summaries on re-generate" do
      locked = create(:attendance_summary, :locked, tenant: tenant, employee: employee,
                      month: 1, year: 2025, total_working_days: 20, days_present: 18)
      generator.call
      expect(locked.reload.total_working_days).to eq(20)   # unchanged
    end

    it "updates days_present on draft summaries from re-generate while preserving HR edits" do
      draft = create(:attendance_summary, tenant: tenant, employee: employee,
                     month: 1, year: 2025, total_working_days: 22, days_present: 15)
      generator.call
      # days_present is preserved as HR already edited it (15)
      expect(draft.reload.days_present).to eq(15)
    end

    it "pro-rates leave days that span across month boundaries" do
      # Leave from Dec 30, 2024 to Jan 3, 2025 — only Jan 2,3 count for January
      lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: paid_type,
                 from_date: Date.new(2024, 12, 30), to_date: Date.new(2025, 1, 3))
      lr.save(validate: false)

      generator.call
      summary = AttendanceSummary.find_by(employee: employee, month: 1, year: 2025)
      # Jan 1 (Wed), Jan 2 (Thu), Jan 3 (Fri) = 3 business days in January
      expect(summary.approved_leaves).to eq(3)
    end
  end
end
