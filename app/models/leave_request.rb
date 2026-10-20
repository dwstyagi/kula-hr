class LeaveRequest < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :leave_type
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :leave_balance_debits, dependent: :destroy
  has_many :comp_off_usages, dependent: :destroy

  enum :duration, { full_day: "full_day", morning: "morning", afternoon: "afternoon" }, prefix: true, validate: true
  validates :regularization_note, length: { maximum: 1000 }
  validate :half_day_is_single_date

  def half_day? = !duration_full_day?
  def regularization? = regularization_note.present?
  def hr_approval_required? = regularization? || employee.hr_is_approver?
  def duration_label = half_day? ? "Half day — #{duration}" : "Full day"

  def daily_units
    working_dates.index_with { half_day? ? 0.5.to_d : 1.to_d }
  end

  enum :status, { pending: 0, approved: 1, rejected: 2, cancelled: 3 }

  before_validation :calculate_number_of_days, if: -> { new_record? || from_date_changed? || to_date_changed? || leave_type_id_changed? || duration_changed? }

  validates :from_date, :to_date, presence: true
  validates :number_of_days, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
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

  def working_dates
    return [] unless from_date && to_date && to_date >= from_date

    pattern = employee&.tenant&.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
    holidays = Holiday.active.applicable_to(employee&.work_location_id)
      .where(date: from_date..to_date).pluck(:date).to_set
    (from_date..to_date).select do |date|
      Attendance::WorkingDaysCalculator.working_day?(date, pattern) && !holidays.include?(date)
    end
  end

  def days_by_financial_year
    daily_units.group_by { |date, _units| FinancialYear.label(date) }.transform_values { |days| days.sum { |_date, units| units } }
  end

  private

  def half_day_is_single_date
    errors.add(:duration, "requires the same From and To date") if half_day? && from_date != to_date
  end

  def calculate_number_of_days
    return unless from_date.present? && to_date.present? && to_date >= from_date

    self.number_of_days = daily_units.values.sum
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
    if from_date < Date.current && regularization_note.blank?
      errors.add(:regularization_note, "is required for past dates; HR must review the correction")
    end
    if employee && from_date < employee.joining_date
      errors.add(:from_date, "cannot be before the joining date")
    end
  end

  def no_overlapping_requests
    return unless from_date.present? && to_date.present? && employee.present?

    overlapping = LeaveRequest
      .where(employee: employee)
      .where.not(status: [ :rejected, :cancelled ])
      .where("from_date <= ? AND to_date >= ?", to_date, from_date)

    if half_day?
      overlapping = overlapping.where(duration: [ "full_day", duration ])
    end
    errors.add(:base, "overlaps with an existing leave request for those dates") if overlapping.exists?
  end

  def sufficient_balance
    return unless leave_type.present? && number_of_days.present?
    return if leave_type.lop?

    days_by_financial_year.each do |financial_year, days|
      balance = LeaveBalance.find_by(employee: employee, leave_type: leave_type, financial_year: financial_year)
      if balance.nil?
        errors.add(:base, "No #{leave_type.name} balance found for financial year #{financial_year}")
      elsif balance.remaining_days < days
        errors.add(:base, "Insufficient #{leave_type.name} balance for #{financial_year}. You have #{balance.remaining_days} days remaining but requested #{days} days")
      end
    end
  end

  def employee_is_active
    return unless employee.present?
    errors.add(:base, "Cannot apply leave for an inactive employee") unless Employee::IN_SERVICE_STATUSES.include?(employee.employment_status)
  end
end
