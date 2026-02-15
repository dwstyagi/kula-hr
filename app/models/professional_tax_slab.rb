class ProfessionalTaxSlab < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  validates :state, presence: true
  validates :salary_from, numericality: { greater_than_or_equal_to: 0 }
  validates :salary_to, numericality: { greater_than: 0 }
  validates :tax_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :salary_from_less_than_to

  private

  def salary_from_less_than_to
    return if salary_from.blank? || salary_to.blank?

    errors.add(:salary_from, "must be less than salary_to") if salary_from >= salary_to
  end
end
