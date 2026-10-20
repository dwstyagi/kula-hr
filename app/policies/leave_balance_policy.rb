class LeaveBalancePolicy < ApplicationPolicy
  def show?
    admin_or_hr? || record.employee.user_id == user.id
  end

  def adjust?
    admin_or_hr?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.has_role?(:super_admin) || user.has_role?(:hr_admin)
        scope.all
      else
        scope.joins(:employee).where(employees: { user_id: user.id })
      end
    end
  end
end
