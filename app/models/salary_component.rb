class SalaryComponent < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  has_many :salary_structure_components, dependent: :destroy
  has_many :salary_structures, through: :salary_structure_components

  enum :component_type, { earning: "earning", deduction: "deduction", employer_contribution: "employer_contribution" }
  enum :calculation_type, { flat: "flat", percentage: "percentage" }

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :component_type, presence: true
  validates :calculation_type, presence: true
  validates :sort_order, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :earnings, -> { where(component_type: "earning") }
  scope :deductions, -> { where(component_type: "deduction") }
  scope :employer_contributions, -> { where(component_type: "employer_contribution") }
end
