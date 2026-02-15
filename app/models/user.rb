class User < ApplicationRecord
  rolify

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :invitable

  has_many :tenant_users, dependent: :destroy
  has_many :tenants, through: :tenant_users

  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def assign_role(role_name)
    roles.clear
    add_role(role_name)
  end
end
