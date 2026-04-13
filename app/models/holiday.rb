class Holiday < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  validates :name, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: :tenant_id, message: "already has a holiday on this date" }

  scope :active, -> { where(is_active: true) }
end
