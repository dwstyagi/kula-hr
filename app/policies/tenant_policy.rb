class TenantPolicy < ApplicationPolicy
  def show?
    super_admin?
  end

  def update?
    super_admin?
  end
end
