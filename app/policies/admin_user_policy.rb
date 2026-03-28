class AdminUserPolicy < ApplicationPolicy
  def index?   = super_admin?
  def new?     = super_admin?
  def create?  = super_admin?
  def destroy? = super_admin?
end
