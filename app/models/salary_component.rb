class SalaryComponent < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  has_many :salary_structure_components, dependent: :destroy
  has_many :salary_structures, through: :salary_structure_components

  enum :component_type, { earning: "earning", deduction: "deduction", employer_contribution: "employer_contribution" }
  enum :calculation_type, { flat: "flat", percentage: "percentage" }

  # Payroll finds these by name (PF base, HRA exemption, employer-PF carve).
  # Renaming or deleting one would silently zero those calculations.
  RESERVED_NAMES = [ "Basic", "HRA", "DA", "Special Allowance" ].freeze

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validate :reserved_component_unchanged, on: :update
  before_destroy :prevent_reserved_destroy, prepend: true
  validates :component_type, presence: true
  validates :calculation_type, presence: true
  validates :sort_order, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :earnings, -> { where(component_type: "earning") }
  scope :deductions, -> { where(component_type: "deduction") }
  scope :employer_contributions, -> { where(component_type: "employer_contribution") }

  def reserved? = RESERVED_NAMES.include?(name_in_database || name)

  private

  def reserved_component_unchanged
    return unless RESERVED_NAMES.include?(name_in_database)

    if will_save_change_to_name?
      errors.add(:name, "cannot be changed — payroll uses \"#{name_in_database}\" to calculate PF, HRA exemption and allowances")
    end
    if will_save_change_to_component_type?
      errors.add(:component_type, "cannot be changed for #{name_in_database}")
    end
  end

  def prevent_reserved_destroy
    return unless reserved?

    errors.add(:base, "#{name} is used by payroll calculations and cannot be deleted")
    throw :abort
  end
end
