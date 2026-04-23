class CompOffRequest < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :approved_by, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :worked_date, presence: true
  validate :worked_date_in_past,        on: :create
  validate :worked_date_is_non_working, on: :create
  validate :no_active_request_for_date, on: :create

  scope :pending_approval, -> { where(status: :pending) }
  scope :for_employee, ->(emp) { where(employee: emp) }

  private

  def worked_date_in_past
    return unless worked_date.present?
    errors.add(:worked_date, "must be in the past") if worked_date >= Date.today
  end

  def worked_date_is_non_working
    return unless worked_date.present? && employee.present?

    pattern  = employee.tenant.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
    is_weekend = !Attendance::WorkingDaysCalculator.working_day?(worked_date, pattern)
    is_holiday = Holiday.active.exists?(date: worked_date)

    unless is_weekend || is_holiday
      errors.add(:worked_date, "must be a public holiday or weekend — regular working days are not eligible for comp-off")
    end
  end

  def no_active_request_for_date
    return unless worked_date.present? && employee.present?

    active = CompOffRequest
      .where(employee: employee, worked_date: worked_date)
      .where(status: [ :pending, :approved ])

    if active.exists?
      status_label = active.first.status
      errors.add(:base, "You already have a #{status_label} comp-off request for #{worked_date.strftime('%d %b %Y')}")
    end
  end
end
