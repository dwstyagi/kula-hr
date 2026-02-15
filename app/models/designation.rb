class Designation < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  has_paper_trail

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
end
