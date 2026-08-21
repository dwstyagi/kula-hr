class FullAndFinalSettlement < ApplicationRecord
  acts_as_tenant :tenant

  EARNING_COMPONENTS = {
    earned_salary: "Salary until Last Working Date",
    leave_encashment: "Leave Encashment",
    bonus: "Bonus / Incentive",
    notice_pay: "Notice Pay",
    gratuity: "Gratuity",
    other_earnings: "Other Earnings"
  }.freeze

  DEDUCTION_COMPONENTS = {
    notice_recovery: "Notice Recovery",
    loan_recovery: "Loan / Advance Recovery",
    asset_recovery: "Asset Recovery",
    other_deductions: "Other Deductions",
    pf_amount: "PF",
    esi_amount: "ESI",
    professional_tax_amount: "Professional Tax",
    tds_amount: "TDS"
  }.freeze

  MONEY_FIELDS = (EARNING_COMPONENTS.keys + DEDUCTION_COMPONENTS.keys).freeze

  belongs_to :tenant
  belongs_to :payroll_run
  belongs_to :employee
  belongs_to :payslip, optional: true

  validates :last_working_date, presence: true
  validates :payroll_run_id, uniqueness: true
  validates :salary_days, :leave_encashment_days, numericality: { greater_than_or_equal_to: 0 }
  validates(*MONEY_FIELDS, numericality: { greater_than_or_equal_to: 0 })
  validate :run_must_be_full_and_final
  validate :employee_and_run_share_tenant
  validate :last_working_date_after_joining
  validate :payment_not_before_last_working_date
  validate :no_other_open_settlement, on: :create

  # Statuses that still make an employee payroll-eligible. Anyone already
  # resigned or terminated keeps the status HR set, so a dismissal is never
  # relabelled as a resignation by the settlement.
  IN_SERVICE_STATUSES = %w[active probation notice_period].freeze

  # Closes the employee out of payroll. Called when the run is approved — the
  # point where payslips lock and the payout is committed. Until this runs the
  # employee stays payroll-eligible, so the next regular run would pay full
  # salary on top of the settlement.
  def close_out_employee!
    attrs = { last_working_date: last_working_date }
    attrs[:employment_status] = "resigned" if IN_SERVICE_STATUSES.include?(employee.employment_status)
    employee.update!(attrs)
  end

  def earning_items
    component_items(EARNING_COMPONENTS)
  end

  def deduction_items
    component_items(DEDUCTION_COMPONENTS)
  end

  def total_earnings
    EARNING_COMPONENTS.keys.sum { |field| public_send(field).to_d }
  end

  def total_deductions
    DEDUCTION_COMPONENTS.keys.sum { |field| public_send(field).to_d }
  end

  def net_pay
    [ total_earnings - total_deductions, 0 ].max
  end

  def recoverable_amount
    [ total_deductions - total_earnings, 0 ].max
  end

  private

  def component_items(mapping)
    mapping.filter_map do |field, label|
      amount = public_send(field).to_d
      [ label, amount ] if amount.positive?
    end
  end

  def run_must_be_full_and_final
    errors.add(:payroll_run, "must be a full-and-final run") unless payroll_run&.full_and_final?
  end

  def employee_and_run_share_tenant
    return unless tenant && employee && payroll_run
    return if employee.tenant_id == tenant_id && payroll_run.tenant_id == tenant_id

    errors.add(:base, "employee and payroll run must belong to the same company")
  end

  def last_working_date_after_joining
    return if last_working_date.blank? || employee&.joining_date.blank?

    errors.add(:last_working_date, "cannot be before joining date") if last_working_date < employee.joining_date
  end

  def payment_not_before_last_working_date
    return if last_working_date.blank? || payroll_run&.payment_date.blank?

    if payroll_run.payment_date < last_working_date
      errors.add(:base, "Payment date cannot be before the last working date")
    end
  end

  def no_other_open_settlement
    return unless employee

    duplicate = self.class.joins(:payroll_run)
      .where(employee_id: employee_id)
      .where.not(payroll_runs: { status: "rejected" })
      .where.not(id: id)
      .exists?
    errors.add(:employee, "already has an open or completed F&F settlement") if duplicate
  end
end
