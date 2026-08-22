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

  # Only Super Admin can approve or reject. This is deliberately identical for
  # regular and off-cycle runs: a super admin can already raise and approve a
  # regular run, so blocking them on the smaller off-cycle amount would be an
  # inconsistency that protects nothing. Segregation of duties, if it is ever
  # needed, belongs in the audit trail (initiated_by / approved_by) rather than
  # in a hard block that a single-super-admin tenant cannot satisfy.
  def approve? = super_admin?
  def reject?  = super_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
