class LeaveRequestPolicy < ApplicationPolicy
  # Employees can apply; HR/admin can do everything
  def create?
    admin_or_hr? || employee?
  end

  def new?
    create?
  end

  # Detail drawer on the admin queue; managers and owners may also look.
  def show?
    admin_or_hr? || is_reporting_manager? || own_record?
  end

  # Queue-level action — per-record approve? is still checked for each request.
  def bulk_approve?
    admin_or_hr?
  end

  # Employees can cancel their own pending requests; HR/admin can cancel any
  def cancel?
    admin_or_hr? || (employee? && own_record? && record.pending?)
  end

  # HR/admin can approve or reject any request; reporting manager can approve/reject their direct report's request
  def approve?
    admin_or_hr? || is_reporting_manager?
  end

  def reject?
    admin_or_hr? || is_reporting_manager?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.has_role?(:super_admin) || user.has_role?(:hr_admin)
        scope.all
      else
        # Employees see only their own requests
        employee = Employee.find_by(user: user)
        employee ? scope.where(employee: employee) : scope.none
      end
    end
  end

  private

  def own_record?
    employee = Employee.find_by(user: user)
    employee && record.employee_id == employee.id
  end

  def is_reporting_manager?
    return false unless user
    manager_employee = Employee.find_by(user: user)
    return false unless manager_employee
    record.employee.reporting_manager_id == manager_employee.id
  end
end
