class EmployeeSalary < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :salary_structure

  validates :annual_ctc, presence: true, numericality: { greater_than: 0 }
  validates :effective_from, presence: true
  validate :effective_to_after_effective_from

  scope :current, -> { where(effective_to: nil) }
  scope :history, -> { where.not(effective_to: nil).order(effective_from: :desc) }

  def current?
    effective_to.nil?
  end

  def monthly_ctc
    (annual_ctc / 12.0).round(2)
  end

  private

  def effective_to_after_effective_from
    return if effective_from.blank? || effective_to.blank?
    errors.add(:effective_to, "must be after effective from date") if effective_to <= effective_from
  end
end
