class LeaveRequest < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :leave_type
  belongs_to :approved_by, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2, cancelled: 3 }

  before_validation :calculate_number_of_days

  validates :from_date, :to_date, presence: true
  validates :number_of_days, numericality: { greater_than: 0 }, allow_nil: true
  validates :reason, length: { maximum: 500 }

  validate :to_date_on_or_after_from_date
  validate :from_date_not_in_past,    on: :create
  validate :working_days_present,     on: :create
  validate :no_overlapping_requests,  on: :create
  validate :sufficient_balance,       on: :create
  validate :employee_is_active,       on: :create

  scope :pending_approval, -> { where(status: :pending) }
  scope :for_employee, ->(emp) { where(employee: emp) }
  scope :for_month, ->(month, year) {
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month
    where("from_date <= ? AND to_date >= ?", end_date, start_date)
  }

  private

  def calculate_number_of_days
    return unless from_date.present? && to_date.present? && to_date >= from_date

    pattern       = employee&.tenant&.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
    holiday_dates = Holiday.active.where(date: from_date..to_date).pluck(:date).to_set

    self.number_of_days = (from_date..to_date).count do |d|
      Attendance::WorkingDaysCalculator.working_day?(d, pattern) && !holiday_dates.include?(d)
    end
  end

  def working_days_present
    return unless from_date.present? && to_date.present? && to_date >= from_date
    return if number_of_days.nil?

    if number_of_days == 0
      errors.add(:base, "The selected date(s) fall entirely on non-working days. Please choose working days.")
    end
  end

  def to_date_on_or_after_from_date
    return unless from_date.present? && to_date.present?
    errors.add(:to_date, "must be on or after the start date") if to_date < from_date
  end

  def from_date_not_in_past
    return unless from_date.present?
    errors.add(:from_date, "cannot be in the past") if from_date < Date.today
  end

  def no_overlapping_requests
    return unless from_date.present? && to_date.present? && employee.present?

    overlapping = LeaveRequest
      .where(employee: employee)
      .where.not(status: [ :rejected, :cancelled ])
      .where("from_date <= ? AND to_date >= ?", to_date, from_date)

    errors.add(:base, "overlaps with an existing leave request for those dates") if overlapping.exists?
  end

  def sufficient_balance
    return unless leave_type.present? && number_of_days.present?
    return if leave_type.lop?

    balance = LeaveBalance.find_by(
      employee: employee,
      leave_type: leave_type,
      financial_year: LeaveBalance.current_financial_year
    )

    if balance.nil?
      errors.add(:base, "No #{leave_type.name} balance found for the current financial year")
    elsif balance.remaining_days < number_of_days
      errors.add(:base, "Insufficient #{leave_type.name} balance. You have #{balance.remaining_days} days remaining but requested #{number_of_days} days")
    end
  end

  def employee_is_active
    return unless employee.present?
    errors.add(:base, "Cannot apply leave for an inactive employee") unless employee.active?
  end
end
