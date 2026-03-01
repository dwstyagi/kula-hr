class PayslipLineItem < ApplicationRecord
  belongs_to :payslip

  COMPONENT_TYPES = %w[earning deduction].freeze
  CATEGORIES      = %w[fixed variable statutory].freeze

  validates :component_name, presence: true
  validates :component_type, presence: true, inclusion: { in: COMPONENT_TYPES }
  validates :amount,         presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :category,       inclusion: { in: CATEGORIES }, allow_blank: true

  scope :earnings,   -> { where(component_type: "earning").order(:sort_order) }
  scope :deductions, -> { where(component_type: "deduction").order(:sort_order) }

  def earning?
    component_type == "earning"
  end

  def deduction?
    component_type == "deduction"
  end

  # How much was reduced due to LOP proration
  def prorated_reduction
    return 0 if full_amount.nil?
    (full_amount - amount).round(2)
  end
end
