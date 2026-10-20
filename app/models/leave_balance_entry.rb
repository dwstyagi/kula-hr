class LeaveBalanceEntry < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :leave_balance
  belongs_to :actor, class_name: "User", optional: true
  validates :kind, presence: true
  def readonly? = persisted?
end
