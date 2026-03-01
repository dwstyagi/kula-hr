class PayslipPolicy < ApplicationPolicy
  def index?  = admin_or_hr?
  def show?   = admin_or_hr?
  def edit?   = admin_or_hr? && !record.locked?
  def update? = admin_or_hr? && !record.locked?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
