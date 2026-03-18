class ImportPolicy < ApplicationPolicy
  def new?             = admin_or_hr?
  def download_errors? = admin_or_hr?

  def create?
    return false if current_tenant&.trial?
    admin_or_hr?
  end

  alias preview?  create?
  alias confirm?  create?
end
