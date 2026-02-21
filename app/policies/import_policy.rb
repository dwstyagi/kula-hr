class ImportPolicy < ApplicationPolicy
  def new?
    admin_or_hr?
  end

  def create?
    admin_or_hr?
  end
end
