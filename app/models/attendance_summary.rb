class AttendanceSummary < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee

  enum :status, { draft: 0, locked: 1 }

  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year,  presence: true
  validates :employee_id, uniqueness: { scope: [:month, :year],
                                        message: "already has an attendance summary for this month" }

  scope :for_month, ->(month, year) { where(month: month, year: year) }
  scope :for_tenant_month, ->(tenant, month, year) { where(tenant: tenant, month: month, year: year) }

  before_save :recalculate_derived_fields

  def month_name
    Date::MONTHNAMES[month]
  end

  def period_label
    "#{month_name} #{year}"
  end

  # Called by LopCalculator and payroll services in Sprint 6
  def proration_factor
    return 1.0 if total_working_days.zero?
    (paid_days / total_working_days).round(6)
  end

  private

  def recalculate_derived_fields
    effective_present = days_present + (half_days * 0.5)
    raw_absent = total_working_days - effective_present - approved_leaves - lop_leaves
    self.unapproved_absences = [raw_absent, 0].max
    self.lop_days             = unapproved_absences + lop_leaves
    self.paid_days            = [total_working_days - lop_days, 0].max
  end
end
