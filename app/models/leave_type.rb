class LeaveType < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :annual_quota, numericality: { greater_than_or_equal_to: 0 }
  validates :max_carry_forward, numericality: { greater_than_or_equal_to: 0 }
end
