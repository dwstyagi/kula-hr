class LeaveRequestEvent < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :leave_request
  belongs_to :actor, class_name: "User", optional: true
  validates :action, presence: true
  def readonly? = persisted?
end
