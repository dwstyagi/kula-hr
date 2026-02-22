class AttendanceSummaryPolicy < ApplicationPolicy
  def index?             = admin_or_hr?
  def show?              = admin_or_hr?                    # view the read-only row (cancel link)
  def edit?              = admin_or_hr? && record.draft?   # open edit form
  def update?            = admin_or_hr? && record.draft?   # save changes
  def generate?          = admin_or_hr?
  def lock_month?        = admin_or_hr?
  def download_template? = admin_or_hr?
  def upload_template?   = admin_or_hr?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
