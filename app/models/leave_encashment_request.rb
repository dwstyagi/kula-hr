class LeaveEncashmentRequest < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :leave_type
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :payslip, optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2, paid: 3 }

  validates :financial_year, presence: true
  validates :number_of_days, numericality: { greater_than: 0 }
  validate :leave_type_must_be_encashable,   on: :create
  validate :only_in_march,                   on: :create
  validate :no_duplicate_request_for_fy,     on: :create
  validate :employee_has_carry_forward_days, on: :create

  scope :for_year, ->(fy) { where(financial_year: fy) }
  scope :current,  -> { for_year(LeaveBalance.current_financial_year) }
  # Approved encashments not yet paid out through a payslip — picked up by PayrollProcessor.
  scope :payable,  -> { where(status: :approved, payslip_id: nil).where.not(encashment_amount: nil) }

  private

  def leave_type_must_be_encashable
    return unless leave_type
    unless leave_type.carry_forward? && !leave_type.lop?
      errors.add(:base, "#{leave_type.name} is not eligible for encashment")
    end
  end

  def only_in_march
    unless Date.today.month == 3
      errors.add(:base, "Encashment requests can only be submitted in March")
    end
  end

  def no_duplicate_request_for_fy
    return unless employee && leave_type && financial_year
    if LeaveEncashmentRequest.exists?(employee: employee, leave_type: leave_type, financial_year: financial_year)
      errors.add(:base, "You have already submitted an encashment request for #{leave_type.name} this financial year")
    end
  end

  def employee_has_carry_forward_days
    return unless employee && leave_type && financial_year

    balance = LeaveBalance.find_by(
      employee: employee,
      leave_type: leave_type,
      financial_year: financial_year
    )

    eligible = balance ? [ leave_type.max_carry_forward, balance.remaining_days ].min : 0
    if eligible <= 0
      errors.add(:base, "You have no carry-forward eligible #{leave_type.name} days to encash")
    end
  end
end
