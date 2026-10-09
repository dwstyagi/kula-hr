class PayslipPolicy < ApplicationPolicy
  def index?  = admin_or_hr? || own_payslip?
  def show?   = admin_or_hr? || own_payslip?
  # Payslips can be corrected only before the run is submitted for approval,
  # or after it is rejected. Once under review, the approver must see the
  # figures they approve; once approved, payslips are locked.
  EDITABLE_RUN_STATES = %w[processed rejected].freeze
  def edit?   = admin_or_hr? && !record.locked? && !record.full_and_final? &&
                record.payroll_run.status.in?(EDITABLE_RUN_STATES)
  def update? = edit?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.has_role?(:super_admin) || user.has_role?(:hr_admin)
        scope.all
      elsif user.has_role?(:employee)
        employee = Employee.find_by(user: user)
        return scope.none unless employee
        # Employees only see approved/paid payslips for themselves
        scope.joins(:payroll_run)
             .where(employee: employee)
             .where(payroll_runs: { status: %w[approved paid] })
      else
        scope.none
      end
    end
  end

  private

  def own_payslip?
    employee = Employee.find_by(user: user)
    employee.present? &&
      record.employee_id == employee.id &&
      record.payroll_run.status.in?(%w[approved paid])
  end
end
