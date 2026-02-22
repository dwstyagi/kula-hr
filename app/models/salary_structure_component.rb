class SalaryStructureComponent < ApplicationRecord
  belongs_to :salary_structure
  belongs_to :salary_component

  validates :value, presence: true, numericality: { greater_than: 0 }
  validates :salary_component_id, uniqueness: { scope: :salary_structure_id, message: "has already been added to this structure" }

  delegate :name, :component_type, :calculation_type, :taxable?, to: :salary_component
end
