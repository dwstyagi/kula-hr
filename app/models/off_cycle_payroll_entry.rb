class OffCyclePayrollEntry < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :tenant
  belongs_to :payroll_run
  belongs_to :employee

  validates :gross_amount, numericality: { greater_than: 0 }
  validates :tds_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: :payroll_run_id }
  validate :tds_cannot_exceed_gross
  validate :employee_and_run_share_tenant
  validate :run_must_be_off_cycle

  def net_amount
    gross_amount - tds_amount
  end

  private

  def tds_cannot_exceed_gross
    return if gross_amount.blank? || tds_amount.blank?

    errors.add(:tds_amount, "cannot exceed gross amount") if tds_amount > gross_amount
  end

  def employee_and_run_share_tenant
    return unless tenant && employee && payroll_run

    unless employee.tenant_id == tenant_id && payroll_run.tenant_id == tenant_id
      errors.add(:base, "employee and payroll run must belong to the same company")
    end
  end

  def run_must_be_off_cycle
    errors.add(:payroll_run, "must be an off-cycle run") if payroll_run&.regular?
  end
end
