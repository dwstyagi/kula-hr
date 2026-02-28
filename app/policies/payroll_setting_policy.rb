class PayrollSettingPolicy < ApplicationPolicy
  def show?
    admin_or_hr?
  end

  def update?
    super_admin?
  end

  def edit?
    update?
  end
end
