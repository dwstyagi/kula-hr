class PayrollRun < ApplicationRecord
  include AASM

  acts_as_tenant(:tenant)
  belongs_to :tenant
  belongs_to :initiated_by, class_name: "User"
  belongs_to :approved_by,  class_name: "User", optional: true
  has_many   :payslips, dependent: :destroy

  # ── Validations ──────────────────────────────────────────────────────────────

  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year,  presence: true
  validate  :no_existing_run_for_period, on: :create
  validate  :attendance_must_be_locked, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────────

  scope :recent, -> { order(year: :desc, month: :desc) }
  scope :for_month, ->(month, year) { where(month: month, year: year) }

  # ── AASM State Machine ───────────────────────────────────────────────────────

  aasm column: :status do
    state :draft,        initial: true
    state :processing
    state :processed
    state :under_review
    state :approved
    state :rejected
    state :paid

    # draft → processing (kicked off by PayrollProcessingJob)
    event :start_processing do
      transitions from: :draft, to: :processing
    end

    # processing → processed (called by PayrollProcessor after all employees done)
    event :finish_processing do
      transitions from: :processing, to: :processed
    end

    # processed → under_review (HR submits for Super Admin approval)
    event :submit_for_review do
      transitions from: :processed, to: :under_review
    end

    # under_review → approved (Super Admin only — enforced by Pundit)
    event :approve do
      transitions from: :under_review, to: :approved
    end

    # under_review → rejected (Super Admin rejects with reason)
    event :reject do
      transitions from: :under_review, to: :rejected
    end

    # rejected → under_review (HR fixes payslips inline and resubmits — no wipe)
    event :resubmit_for_review do
      transitions from: :rejected, to: :under_review
    end

    # rejected or processed → draft (HR reprocesses — wipes all payslips)
    event :reprocess do
      transitions from: [ :rejected, :processed ], to: :draft, after: :clear_payslips
    end

    # approved → paid (after bank transfer is done)
    event :mark_paid do
      transitions from: :approved, to: :paid
    end
  end

  # Called from controller after approve! so we have access to current_user
  def record_approval(approver)
    update_columns(approved_by_id: approver.id, approved_at: Time.current)
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Smart default for the "new payroll run" form: the month right after the
  # tenant's most recent run, not the calendar's current month (HR usually
  # runs payroll for the *previous* month a few days into the next one).
  def self.next_unprocessed_period
    last = recent.first
    return [ Date.today.month, Date.today.year ] unless last

    next_period = Date.new(last.year, last.month, 1).next_month
    [ next_period.month, next_period.year ]
  end

  def month_name
    Date::MONTHNAMES[month]
  end

  def period_label
    "#{month_name} #{year}"
  end

  def progress_percentage
    return 0 if total_employees.zero?
    ((processed_employees.to_f / total_employees) * 100).round
  end

  private

  # Guard: one payroll run per tenant/month/year. Instead of a generic
  # "already exists" message, name who initiated it and its current state so
  # HR understands why a new run is blocked.
  def no_existing_run_for_period
    return if month.blank? || year.blank?

    existing = PayrollRun
      .where(tenant_id: tenant_id || ActsAsTenant.current_tenant&.id, month: month, year: year)
      .where.not(id: id)
      .first
    return unless existing

    initiator = existing.initiated_by&.full_name || "an unknown user"
    detail =
      if existing.approved? || existing.paid?
        approver = existing.approved_by&.full_name || "a super admin"
        "was initiated by #{initiator} and #{existing.approved? ? 'approved' : 'paid'} by #{approver}"
      else
        "was initiated by #{initiator} and is currently #{existing.status.humanize.downcase}"
      end

    errors.add(:base, "Payroll for #{month_name} #{year} #{detail}.")
  end

  # Guard: every active/probation employee must have a locked attendance summary
  # before a run can be created. Delegates to Payroll::ReadinessCheck so the
  # creation error, the new-page panel, and the processor never disagree.
  def attendance_must_be_locked
    readiness = Payroll::ReadinessCheck.new(
      month: month, year: year, tenant: tenant || ActsAsTenant.current_tenant
    ).call
    return if readiness.can_create?

    blocked = readiness.blocking.map { |s| s.employee.full_name }.sort
    names = blocked.first(10).join(", ")
    names += ", and #{blocked.size - 10} more" if blocked.size > 10
    errors.add(:base,
      "Attendance not locked for #{blocked.size} employee(s) for #{month_name} #{year}: #{names}.")
  end

  # Callback: wipe all payslips and reset totals when reprocessing
  def clear_payslips
    payslips.destroy_all
    update_columns(
      processed_employees: 0,
      total_gross: 0,
      total_deductions: 0,
      total_net_pay: 0,
      total_employer_cost: 0
    )
  end
end
