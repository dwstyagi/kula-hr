class Payslip < ApplicationRecord
  acts_as_tenant(:tenant)
  belongs_to :tenant
  belongs_to :payroll_run
  belongs_to :employee
  has_many :line_items, class_name: "PayslipLineItem", dependent: :destroy
  has_many :leave_encashment_requests, dependent: :nullify
  has_one :full_and_final_settlement, dependent: :nullify

  STATUSES = %w[generated revised locked].freeze

  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year,  presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :employee_id, uniqueness: { scope: :payroll_run_id,
              message: "already has a payslip for this payroll run" }

  scope :for_month,  ->(m, y) { where(month: m, year: y) }
  scope :revised,    -> { where(is_revised: true) }
  scope :locked,     -> { where(status: "locked") }

  def locked?    = status == "locked"
  def revised?   = status == "revised"
  def generated? = status == "generated"

  # ── Scoped line item helpers ─────────────────────────────────────────────────

  def earnings
    line_items.where(component_type: "earning").order(:sort_order)
  end

  def deductions
    line_items.where(component_type: "deduction").order(:sort_order)
  end

  # ── Computed helpers ─────────────────────────────────────────────────────────

  # Total cost to the company for this employee this month — includes every
  # employer-side charge (PF, ESI, PF admin, EDLI). When the tenant runs the
  # "employer PF in CTC" model these are carved out of gross, so this still
  # reconciles to the offered CTC.
  def ctc_this_month
    gross_pay + employer_pf + employer_esi + employer_pf_admin + employer_edli
  end

  def proration_factor
    return 1.0 if total_working_days.zero?
    (paid_days / total_working_days).round(4)
  end

  def month_name
    Date::MONTHNAMES[month]
  end

  def off_cycle?
    payroll_run&.off_cycle? || false
  end

  def full_and_final?
    payroll_run&.full_and_final? || false
  end

  def document_title
    return "Full & Final Statement" if full_and_final?
    return "Off-cycle Payslip" if off_cycle?

    "Salary Slip"
  end

  def recoverable_amount
    full_and_final_settlement&.recoverable_amount.to_d
  end

  def period_label
    return payroll_run.period_label if payroll_run&.off_cycle?

    "#{month_name} #{year}"
  end

  # Recalculate headline totals from current line items (used after inline edits)
  def recalculate_totals!
    self.gross_pay        = line_items.where(component_type: "earning").sum(:amount)
    self.total_deductions = line_items.where(component_type: "deduction").sum(:amount)
    self.net_pay          = [ gross_pay - total_deductions, 0 ].max
    save!
  end
end
