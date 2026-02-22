class LeaveRequestPolicy < ApplicationPolicy
  # Employees can apply; HR/admin can do everything
  def create?
    admin_or_hr? || employee?
  end

  def new?
    create?
  end

  # Employees can cancel their own pending requests; HR/admin can cancel any
  def cancel?
    admin_or_hr? || (employee? && own_record? && record.pending?)
  end

  # Only HR/admin can approve or reject
  def approve?
    admin_or_hr?
  end

  def reject?
    admin_or_hr?
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
end
