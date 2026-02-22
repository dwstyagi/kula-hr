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

  scope :active, -> { where(is_active: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :lop, -> { where(is_paid: false) }

  def lop?
    !is_paid?
  end
end
