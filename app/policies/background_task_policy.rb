class BackgroundTaskPolicy < ApplicationPolicy
  def show? = admin_or_hr?
  def retry_task? = admin_or_hr?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
