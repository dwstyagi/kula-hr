class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    admin_or_hr?
  end

  def show?
    admin_or_hr?
  end

  def create?
    admin_or_hr?
  end

  def new?
    create?
  end

  def update?
    admin_or_hr?
  end

  def edit?
    update?
  end

  def destroy?
    super_admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end

  private

  def super_admin?
    user&.has_role?(:super_admin)
  end

  def hr_admin?
    user&.has_role?(:hr_admin)
  end

  def admin_or_hr?
    super_admin? || hr_admin?
  end

  def employee?
    user&.has_role?(:employee)
  end
end
