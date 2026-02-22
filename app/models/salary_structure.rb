class SalaryStructure < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  has_many :salary_structure_components, dependent: :destroy
  has_many :salary_components, through: :salary_structure_components

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(active: true) }

  def component_count
    salary_structure_components.size
  end

  def total_percentage
    salary_structure_components
      .joins(:salary_component)
      .where(salary_components: { calculation_type: "percentage" })
      .sum(:value)
  end
end
