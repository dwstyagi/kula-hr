class LeaveEncashmentRequestPolicy < ApplicationPolicy
  def index?   = admin_or_hr?
  def approve? = admin_or_hr?
  def reject?  = admin_or_hr?
end
