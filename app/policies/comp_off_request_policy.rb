class CompOffRequestPolicy < ApplicationPolicy
  def index? = admin_or_hr?

  # HR can decide any request; a reporting manager only their direct reports'.
  def approve? = admin_or_hr? || reporting_manager?
  def reject?  = approve?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.has_role?(:super_admin) || user.has_role?(:hr_admin)

      manager = Employee.find_by(user: user)
      manager ? scope.where(employee: manager.direct_reports) : scope.none
    end
  end

  private

  def reporting_manager?
    manager = Employee.find_by(user: user)
    manager.present? && record.employee.reporting_manager_id == manager.id
  end
end
