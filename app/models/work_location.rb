class WorkLocation < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  has_many :holidays, dependent: :nullify
  has_many :employees, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(is_active: true) }
end
