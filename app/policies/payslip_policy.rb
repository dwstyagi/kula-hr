class PayslipPolicy < ApplicationPolicy
  def index?  = admin_or_hr? || own_payslip?
  def show?   = admin_or_hr? || own_payslip?
  def edit?   = admin_or_hr? && !record.locked?
  def update? = admin_or_hr? && !record.locked?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.has_role?(:employee)
        employee = Employee.find_by(user: user)
        return scope.none unless employee
        # Employees only see approved/paid payslips for themselves
        scope.joins(:payroll_run)
             .where(employee: employee)
             .where(payroll_runs: { status: %w[approved paid] })
      else
        scope.all
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
