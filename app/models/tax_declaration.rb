class TaxDeclaration < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee

  has_many :investment_declarations, dependent: :destroy

  enum :regime, { old_regime: 0, new_regime: 1 }, prefix: true
  enum :status, { draft: 0, submitted: 1, verified: 2 }, prefix: true

  RENTAL_CITIES = %w[metro non_metro].freeze

  accepts_nested_attributes_for :investment_declarations,
                                allow_destroy: true,
                                reject_if: :all_blank

  validates :financial_year, presence: true,
                             format: { with: /\A\d{4}-\d{2}\z/, message: "must be in format YYYY-YY (e.g. 2025-26)" },
                             uniqueness: { scope: :employee_id }
  validates :monthly_rent,        numericality: { greater_than_or_equal_to: 0 }
  validates :home_loan_interest,  numericality: { greater_than_or_equal_to: 0 }
  validates :home_loan_principal, numericality: { greater_than_or_equal_to: 0 }
  validates :rental_city, inclusion: { in: RENTAL_CITIES }, allow_blank: true

  validate :landlord_pan_required_for_high_rent
  validate :hra_fields_only_for_old_regime

  private

  def landlord_pan_required_for_high_rent
    return unless claiming_hra?
    return unless (monthly_rent.to_f * 12) > 100_000

    errors.add(:landlord_pan, "is required when annual rent exceeds ₹1,00,000") if landlord_pan.blank?
  end

  def hra_fields_only_for_old_regime
    return unless regime_new_regime?

    if claiming_hra?
      errors.add(:claiming_hra, "cannot be claimed under the New Regime")
    end

    if home_loan_interest.to_f > 0
      errors.add(:home_loan_interest, "deduction is not available under the New Regime")
    end
  end
end
