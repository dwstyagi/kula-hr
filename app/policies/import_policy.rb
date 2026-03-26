class ImportPolicy < ApplicationPolicy
  def new?             = admin_or_hr?
  def download_errors? = admin_or_hr?

  def create?  = admin_or_hr?

  alias preview?  create?
  alias confirm?  create?
end
