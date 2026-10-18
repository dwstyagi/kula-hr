require "rails_helper"
require Rails.root.join("db/migrate/20261018000000_track_leave_debits_and_payment_settings")

RSpec.describe "Leave accounting regressions" do
  let(:tenant) { create(:tenant, :active) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:type) { create(:leave_type, tenant: tenant) }

  before do
    travel_to Time.zone.local(2027, 3, 20, 12)
    set_tenant(tenant)
  end
  after { travel_back }

  def balance(year, **attrs)
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: type,
      financial_year: year, **attrs)
  end

  def spanning_request
    create(:leave_request, tenant: tenant, employee: employee, leave_type: type,
      from_date: Date.new(2027, 3, 31), to_date: Date.new(2027, 4, 1))
  end

  it "charges each year and restores those same years after rollover" do
    old = balance("2026-27")
    upcoming = balance("2027-28")
    request = spanning_request
    adjuster = Leave::LeaveBalanceAdjuster.new(leave_request: request)
    adjuster.debit!
    request.update!(status: :approved, approved_at: Time.current)
    expect([ old.reload.used_days, upcoming.reload.used_days ]).to eq([ 1, 1 ])
    travel_to Time.zone.local(2027, 4, 2, 12)
    adjuster.credit!
    adjuster.credit!
    expect([ old.reload.used_days, upcoming.reload.used_days ]).to eq([ 0, 0 ])
    expect([ old.remaining_days, upcoming.remaining_days ]).to eq([ 12, 12 ])
  end

  it "rolls back every year if one balance becomes insufficient before approval" do
    old = balance("2026-27")
    upcoming = balance("2027-28")
    request = spanning_request
    upcoming.update!(remaining_days: 0)
    expect { Leave::LeaveBalanceAdjuster.new(leave_request: request).debit! }
      .to raise_error(Leave::LeaveBalanceAdjuster::InsufficientBalance)
    expect(old.reload.remaining_days).to eq(12)
    expect(request.reload.leave_balance_debits).to be_empty
  end

  it "makes a repeated debit idempotent even before the status write" do
    old = balance("2026-27")
    balance("2027-28")
    request = spanning_request
    2.times { Leave::LeaveBalanceAdjuster.new(leave_request: request).debit! }
    expect(old.reload.used_days).to eq(1)
    expect(request.leave_balance_debits.count).to eq(2)
  end

  it "restores the original debit when a holiday is added after approval" do
    old = balance("2026-27")
    request = create(:leave_request, tenant: tenant, employee: employee, leave_type: type,
      from_date: Date.new(2027, 3, 22), to_date: Date.new(2027, 3, 22))
    adjuster = Leave::LeaveBalanceAdjuster.new(leave_request: request)
    adjuster.debit!
    request.update!(status: :approved, approved_at: Time.current)
    create(:holiday, tenant: tenant, date: request.from_date)
    adjuster.credit!
    request.update!(status: :cancelled)
    expect(old.reload.remaining_days).to eq(12)
    expect(request.number_of_days).to eq(1)
  end

  it "does not approve encashment if another decision has spent its days" do
    earned = create(:leave_type, :earned, tenant: tenant)
    available = create(:leave_balance, tenant: tenant, employee: employee, leave_type: earned,
      total_days: 5, remaining_days: 5)
    request = create(:leave_encashment_request, tenant: tenant, employee: employee,
      leave_type: earned, number_of_days: 5)
    available.update!(used_days: 4, remaining_days: 1)
    expect { request.update!(status: :approved, encashment_amount: 5000) }
      .to raise_error(ActiveRecord::RecordInvalid)
    expect(request.reload).to be_pending
    expect(available.reload.remaining_days).to eq(1)
    expect(available.encashed_days).to eq(0)
  end

  context "comp-off credits" do
    let(:type) { create(:leave_type, tenant: tenant, code: "CO", annual_quota: 0) }

    it "spends the oldest eligible credit and preserves a later credit at expiry" do
      travel_to Time.zone.local(2026, 10, 12, 12)
      type
      first = create(:comp_off_request, tenant: tenant, employee: employee, worked_date: Date.new(2026, 10, 4))
      Leave::CompOffReview.new(request: first, reviewer: create(:user)).approve!
      request = create(:leave_request, tenant: tenant, employee: employee, leave_type: type,
        from_date: Date.new(2026, 10, 13), to_date: Date.new(2026, 10, 13))
      Leave::LeaveBalanceAdjuster.new(leave_request: request).debit!
      request.update!(status: :approved, approved_at: Time.current)
      expect(first.reload.remaining_days).to eq(0)
      travel_to Time.zone.local(2026, 10, 16, 12)
      second = create(:comp_off_request, tenant: tenant, employee: employee, worked_date: Date.new(2026, 10, 11))
      Leave::CompOffReview.new(request: second, reviewer: create(:user)).approve!
      travel_to Time.zone.local(2026, 10, 20, 12)
      Leave::CompOffExpiryJob.perform_now
      expect(LeaveBalance.find_by!(employee: employee, leave_type: type).remaining_days).to eq(1)
      expect(second.reload.remaining_days).to eq(1)
      expect(first.reload).to be_balance_expired
    end

    it "does not reserve credit for leave after that credit expires" do
      travel_to Time.zone.local(2026, 10, 12, 12)
      type
      credit = create(:comp_off_request, tenant: tenant, employee: employee, worked_date: Date.new(2026, 10, 4))
      Leave::CompOffReview.new(request: credit, reviewer: create(:user)).approve!
      request = create(:leave_request, tenant: tenant, employee: employee, leave_type: type,
        from_date: Date.new(2026, 10, 20), to_date: Date.new(2026, 10, 20))
      expect { Leave::LeaveBalanceAdjuster.new(leave_request: request).debit! }
        .to raise_error(Leave::LeaveBalanceAdjuster::InsufficientBalance, /unexpired/)
      expect(credit.reload.remaining_days).to eq(1)
      expect(request.comp_off_usages).to be_empty
    end

    it "backfills legacy credit remainders without consuming pending credits" do
      travel_to Time.zone.local(2026, 10, 18, 12)
      balance("2026-27", total_days: 2, used_days: 1, remaining_days: 1)
      old = create(:comp_off_request, :approved, tenant: tenant, employee: employee,
        worked_date: Date.new(2026, 10, 4), expiry_date: Date.new(2026, 10, 19))
      recent = create(:comp_off_request, :approved, tenant: tenant, employee: employee,
        worked_date: Date.new(2026, 10, 11), expiry_date: Date.new(2026, 10, 24))
      pending = create(:comp_off_request, tenant: tenant, employee: employee, worked_date: Date.new(2026, 10, 17))
      ActiveRecord::Migration.suppress_messages do
        TrackLeaveDebitsAndPaymentSettings.new.reconcile_comp_off_credits
      end
      expect([ old.reload.remaining_days, recent.reload.remaining_days, pending.reload.remaining_days ]).to eq([ 0, 1, 1 ])
    end

    it "restores a still-valid legacy credit when cancelling an older approval" do
      travel_to Time.zone.local(2026, 10, 18, 12)
      available = balance("2026-27", total_days: 1, used_days: 1, remaining_days: 0)
      credit = create(:comp_off_request, :approved, tenant: tenant, employee: employee,
        worked_date: Date.new(2026, 10, 11), approved_at: Time.zone.local(2026, 10, 16),
        expiry_date: Date.new(2026, 10, 23), remaining_days: 0)
      request = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: type,
        from_date: Date.new(2026, 10, 19), to_date: Date.new(2026, 10, 19), approved_at: Time.current)
      request.save!(validate: false)
      Leave::LeaveBalanceAdjuster.new(leave_request: request).credit!
      expect(available.reload.remaining_days).to eq(1)
      expect(credit.reload.remaining_days).to eq(1)
    end
  end
end
