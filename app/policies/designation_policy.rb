class DesignationPolicy < ApplicationPolicy
  def destroy?
    admin_or_hr?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
