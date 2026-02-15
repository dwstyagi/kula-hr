class TenantUser < ApplicationRecord
  belongs_to :tenant
  belongs_to :user

  validates :user_id, uniqueness: { scope: :tenant_id, message: "is already a member of this tenant" }
end
