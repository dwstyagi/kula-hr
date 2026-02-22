class SalaryStructurePolicy < ApplicationPolicy
  def destroy?
    admin_or_hr?
  end

  def add_component?
    admin_or_hr?
  end

  def remove_component?
    admin_or_hr?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
