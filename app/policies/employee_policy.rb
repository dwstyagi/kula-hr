class EmployeePolicy < ApplicationPolicy
  def show?
    admin_or_hr? || record.user_id == user&.id
  end

  def destroy?
    super_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
