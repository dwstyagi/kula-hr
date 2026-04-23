class LeaveType < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  has_many :leave_balances, dependent: :destroy
  has_many :leave_requests, dependent: :restrict_with_error

  WEEK_OFF_PATTERNS = %w[all_saturdays_sundays alternate_saturdays_sundays only_sundays].freeze

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :annual_quota, numericality: { greater_than_or_equal_to: 0 }
  validates :max_carry_forward, numericality: { greater_than_or_equal_to: 0 }
  validate :max_carry_forward_within_quota, if: :carry_forward?

  scope :active, -> { where(is_active: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :lop, -> { where(is_paid: false) }

  def lop?
    !is_paid?
  end

  private

  def max_carry_forward_within_quota
    return unless max_carry_forward.present? && annual_quota.present?

    if max_carry_forward < 1
      errors.add(:max_carry_forward, "must be at least 1 day when carry forward is enabled")
    elsif max_carry_forward >= annual_quota
      errors.add(:max_carry_forward, "must be less than the annual quota (#{annual_quota.to_i} days)")
    end
  end
end
