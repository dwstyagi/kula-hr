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
  validates :month, uniqueness: {
    scope: [ :tenant_id, :year ],
    message: "payroll already exists for this month and year"
  }
  validate :attendance_must_be_locked, on: :create

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

  # Guard: every active/probation employee must have a locked attendance summary
  # before a run can be created. Delegates to Payroll::ReadinessCheck so the
  # creation error, the new-page panel, and the processor never disagree.
  def attendance_must_be_locked
    readiness = Payroll::ReadinessCheck.new(
      month: month, year: year, tenant: tenant || ActsAsTenant.current_tenant
    ).call
    return if readiness.can_create?

    blocked = readiness.blocking.map { |s| s.employee.full_name }.sort
    errors.add(:base,
      "Attendance not locked for #{blocked.size} employee(s) for #{month_name} #{year}: #{blocked.join(', ')}.")
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
