class User < ApplicationRecord
  rolify

  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :timeoutable,
         :invitable

  has_many :tenant_users, dependent: :destroy
  has_many :tenants, through: :tenant_users
  has_one :employee, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end

  # Membership is deliberately checked against tenant_users rather than through
  # any tenant-scoped scope: this is the check that establishes the boundary, so
  # it must not depend on the boundary already being set correctly.
  def member_of?(tenant)
    return false if tenant.nil?

    tenant_users.exists?(tenant_id: tenant.id)
  end

  def active_for_authentication?
    super && account_active?
  end

  def inactive_message
    account_active? ? super : :account_inactive
  end

  def assign_role(role_name)
    roles.clear
    add_role(role_name)
  end
end
