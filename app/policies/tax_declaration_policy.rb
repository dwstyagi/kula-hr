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

  # HR review: submitted declarations count toward TDS straight away; HR
  # verifies the proofs, or sends the declaration back so the employee can fix it.
  def index?           = admin_or_hr?
  def verify?          = admin_or_hr? && record.status_submitted?
  def return_to_draft? = admin_or_hr? && !record.status_draft?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.has_role?(:super_admin) || user.has_role?(:hr_admin)

      employee = Employee.find_by(user: user)
      employee ? scope.where(employee: employee) : scope.none
    end
  end

  private

  def own_record?
    employee = Employee.find_by(user: user)
    employee && record.employee_id == employee.id
  end
end
