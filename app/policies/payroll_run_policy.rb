class PayrollRunPolicy < ApplicationPolicy
  def index?           = admin_or_hr?
  def show?            = admin_or_hr?
  def new?             = admin_or_hr?
  def create?          = admin_or_hr?
  def process_payroll? = admin_or_hr?
  def submit_for_review?    = admin_or_hr?
  def resubmit_for_review?  = admin_or_hr?
  def reprocess?            = admin_or_hr?
  def mark_paid?       = admin_or_hr?
  def progress?        = admin_or_hr?

  def download_bank_file? = admin_or_hr?

  # Only Super Admin can approve or reject
  def approve? = super_admin? && (!record.off_cycle? || record.initiated_by_id != user.id)
  def reject?  = approve?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
