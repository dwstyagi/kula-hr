require "rails_helper"

RSpec.describe "Leave accounting and transitions" do
  let(:tenant) { create(:tenant, :active) }
  let(:actor) { create(:user, :super_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:type) { create(:leave_type, :casual, tenant: tenant) }
  let!(:balance) { create(:leave_balance, tenant: tenant, employee: employee, leave_type: type, total_days: 12, used_days: 0, remaining_days: 12) }
  let(:date) { Date.new(2026, 10, 22) }
  before { set_tenant(tenant) }
  around { |example| travel_to(Time.zone.local(2026, 10, 20, 12)) { example.run } }

  def request_for(duration: "full_day", leave_type: type, from: date, to: date, **attributes)
    create(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
      from_date: from, to_date: to, duration: duration, **attributes)
  end

  def transition(request, action, reason: nil)
    Leave::RequestTransition.new(leave_request: request, actor: actor).call(action, reason: reason)
  end

  it "blocks approval and balance changes when attendance is locked" do
    request = request_for
    summary = create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 10, year: 2026)
    expect { transition(request, :approve) }.to raise_error(Leave::RequestTransition::Error, /locked/)
    expect(request.reload).to be_pending
    expect(balance.reload.remaining_days).to eq(12)
    expect(summary.reload.approved_leaves).to eq(0)
  end

  it "checks every affected month and does not partially debit a cross-month request" do
    request = request_for(from: Date.new(2026, 10, 30), to: Date.new(2026, 11, 2))
    create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 11, year: 2026)
    expect { transition(request, :approve) }.to raise_error(Leave::RequestTransition::Error, /November/)
    expect(balance.reload.remaining_days).to eq(12)
  end

  %w[processing processed under_review approved paid].each do |status|
    it "blocks approval when payroll is #{status}, even without locked attendance" do
      request = request_for
      create(:payroll_run, tenant: tenant, initiated_by: actor, month: 10, year: 2026, status: status)
      expect { transition(request, :approve) }.to raise_error(Leave::RequestTransition::Error, /payroll/)
      expect(balance.reload.remaining_days).to eq(12)
    end
  end

  it "blocks approved cancellation after attendance is locked" do
    request = request_for
    transition(request, :approve)
    create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 10, year: 2026)
    expect { transition(request, :cancel) }.to raise_error(Leave::RequestTransition::Error, /locked/)
    expect(request.reload).to be_approved
    expect(balance.reload.remaining_days).to eq(11)
  end

  it "rechecks balances under lock and cannot approve the same request twice" do
    request = request_for
    balance.update!(remaining_days: 0)
    expect { transition(request, :approve) }.to raise_error(Leave::LeaveBalanceAdjuster::InsufficientBalance)
    balance.update!(remaining_days: 12)
    transition(request, :approve)
    expect { transition(request, :approve) }.to raise_error(Leave::RequestTransition::Error)
    expect(balance.reload.used_days).to eq(1)
  end

  [ 10, 15, 17 ].each do |quota|
    it "credits exactly #{quota} days across a year, including repeating fractions and reruns" do
      type.update!(annual_quota: quota)
      Leave::YearEndProcessingService.new(tenant: tenant, opening_on: Date.new(2027, 4, 1)).call
      11.times do |index|
        service = Leave::MonthlyLeaveAccrualService.new(tenant: tenant, period: Date.new(2027, 5, 1).advance(months: index))
        2.times { service.call }
      end
      next_balance = LeaveBalance.find_by!(employee: employee, leave_type: type, financial_year: "2027-28")
      expect(next_balance.total_days).to eq(quota)
      expect(next_balance.remaining_days).to eq(quota)
    end
  end

  it "does not change the prior FY after rollover has already carried the balance" do
    request = request_for
    Leave::YearEndProcessingService.new(tenant: tenant, opening_on: Date.new(2027, 4, 1)).call
    expect { transition(request, :approve) }.to raise_error(Leave::RequestTransition::Error, /rolled/)
  end
  it "does not encash days already carried into a new financial year" do
    earned = create(:leave_type, :earned, tenant: tenant)
    old = create(:leave_balance, tenant: tenant, employee: employee, leave_type: earned, financial_year: "2026-27", total_days: 10, used_days: 0, remaining_days: 10)
    request = build(:leave_encashment_request, tenant: tenant, employee: employee, leave_type: earned, financial_year: "2026-27", number_of_days: 5)
    request.save!(validate: false)
    Leave::YearEndProcessingService.new(tenant: tenant, opening_on: Date.new(2027, 4, 1)).call
    expect { request.update!(status: :approved) }.to raise_error(ActiveRecord::RecordInvalid, /rolled over/)
    expect(old.reload.remaining_days).to eq(10)
  end

  it "keeps the exact joining allocation on reruns and accrues only eligible subsequent months" do
    type.update!(annual_quota: 10)
    joiner = create(:employee, tenant: tenant, joining_date: Date.current)
    2.times { Leave::LeaveBalanceAllocator.new(employee: joiner).call }
    joining_balance = LeaveBalance.find_by!(employee: joiner, leave_type: type)
    expect(joining_balance.total_days).to eq(Leave::AccrualAmount.for(type, Date.current))
    Leave::MonthlyLeaveAccrualService.new(tenant: tenant, period: Date.current.beginning_of_month).call
    expect(joining_balance.reload.total_days).to eq(Leave::AccrualAmount.for(type, Date.current))
    Leave::MonthlyLeaveAccrualService.new(tenant: tenant, period: Date.current.next_month.beginning_of_month).call
    expect(joining_balance.reload.total_days).to eq(Leave::AccrualAmount.for(type, Date.current) + Leave::AccrualAmount.for(type, Date.current.next_month))
  end
end
