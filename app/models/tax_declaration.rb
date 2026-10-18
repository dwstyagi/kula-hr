class TaxDeclaration < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee

  has_many :investment_declarations, dependent: :destroy

  enum :regime, { old_regime: 0, new_regime: 1 }, prefix: true
  enum :status, { draft: 0, submitted: 1, verified: 2 }, prefix: true

  # Only what the employee has submitted reduces TDS. A draft can change at
  # any time and has not been put forward by the employee.
  scope :effective_for_tds, -> { where(status: [ statuses[:submitted], statuses[:verified] ]) }

  has_paper_trail

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

  def total_declared_investments
    investment_declarations.reject(&:marked_for_destruction?).sum { |investment| investment.declared_amount.to_d }
  end

  def estimated_monthly_tds
    period = Date.new(financial_year.to_s.first(4).to_i, 4, 1)
    salary = employee.salary_for_period(Date.current.month, Date.current.year)
    setting = tenant.payroll_setting
    return 0 unless salary && setting&.tds_enabled?

    breakup = Salary::CtcBreakupCalculator.call(annual_ctc: salary.annual_ctc,
      salary_structure: salary.salary_structure, payroll_setting: setting)
    taxable_names = salary.salary_structure.salary_structure_components
      .select { |component| component.salary_component.taxable? }.map(&:name)
    taxable = breakup.earnings.select { |item| taxable_names.include?(item.name) }.sum(&:annual)
    basic = breakup.earnings.find { |item| item.name == "Basic" }&.monthly || 0
    hra = breakup.earnings.find { |item| item.name == "HRA" }&.monthly || 0
    pf = breakup.deductions.find { |item| item.name == "Employee PF" }&.annual || 0
    Statutory::TdsCalculator.new(employee: employee, annual_gross: taxable,
      monthly_basic: basic, monthly_hra: hra, annual_employee_pf: pf,
      financial_year: financial_year, month: period.month, declaration: self,
      remaining_months: 12).call.monthly_tds
  end

  # Completeness meter for the employee portal dashboard. A submitted/verified
  # declaration is done; a draft only earns partial credit once the employee
  # has actually entered something — no fabricated progress on a blank draft.
  def completeness_percent
    return 100 if status_submitted? || status_verified?
    return 50 if claiming_hra? || monthly_rent.to_f.positive? ||
                 home_loan_interest.to_f.positive? || home_loan_principal.to_f.positive? ||
                 investment_declarations.exists?

    0
  end

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
