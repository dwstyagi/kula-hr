class Payslip < ApplicationRecord
  acts_as_tenant(:tenant)
  belongs_to :tenant
  belongs_to :payroll_run
  belongs_to :employee
  has_many :line_items, class_name: "PayslipLineItem", dependent: :destroy
  has_many :leave_encashment_requests, dependent: :nullify

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

  # Total cost to the company for this employee this month
  def ctc_this_month
    gross_pay + employer_pf + employer_esi
  end

  def proration_factor
    return 1.0 if total_working_days.zero?
    (paid_days / total_working_days).round(4)
  end

  def month_name
    Date::MONTHNAMES[month]
  end

  def period_label
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
