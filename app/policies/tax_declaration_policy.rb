class TaxDeclarationPolicy < ApplicationPolicy
  def show?
    own_record? || admin_or_hr?
  end

  def edit?
    update?
  end

  def update?
    own_record? && record.status_draft?
  end

  def submit?
    own_record? && record.status_draft?
  end

  private

  def own_record?
    employee = Employee.find_by(user: user)
    employee && record.employee_id == employee.id
  end
end
