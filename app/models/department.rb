class Department < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  has_paper_trail

  has_many :employees, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
end
