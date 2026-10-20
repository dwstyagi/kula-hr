class AttendanceSummary < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee

  enum :status, { draft: 0, locked: 1 }

  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year,  presence: true
  validates :days_present, :half_days, :total_working_days, :non_employment_days,
            numericality: { greater_than_or_equal_to: 0 }
  validate :attendance_within_employment_days
  validates :employee_id, uniqueness: { scope: [ :month, :year ],
                                        message: "already has an attendance summary for this month" }

  scope :for_month, ->(month, year) { where(month: month, year: year) }
  scope :for_tenant_month, ->(tenant, month, year) { where(tenant: tenant, month: month, year: year) }

  before_validation :reset_leave_adjustment, if: -> { persisted? && will_save_change_to_days_present? }
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

  def reset_leave_adjustment
    self.leave_adjusted_present_days = 0
  end

  def attendance_within_employment_days
    return unless [ days_present, half_days, total_working_days, non_employment_days ].all? { |value| value.is_a?(Numeric) }

    if non_employment_days > total_working_days || days_present + half_days * 0.5 > total_working_days - non_employment_days
      errors.add(:base, "Attendance cannot exceed the working days during employment")
    end
  end

  # Working days before joining / after the last working day are neither
  # present nor absent: they are excluded from pay without counting as LOP.
  def recalculate_derived_fields
    employed_days = total_working_days - non_employment_days
    effective_present = days_present + (half_days * 0.5)
    raw_absent = employed_days - effective_present - approved_leaves - lop_leaves
    self.unapproved_absences = [ raw_absent, 0 ].max
    self.lop_days             = unapproved_absences + lop_leaves
    self.paid_days            = [ employed_days - lop_days, 0 ].max
  end
end
