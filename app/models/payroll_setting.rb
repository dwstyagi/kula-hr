class PayrollSetting < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  WEEK_OFF_PATTERNS = %w[all_saturdays_sundays alternate_saturdays_sundays only_sundays].freeze
  SUPPORTED_PT_STATES = %w[maharashtra karnataka telangana tamil_nadu west_bengal gujarat andhra_pradesh].freeze

  validates :pf_employee_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :pf_employer_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :pf_wage_ceiling,  numericality: { greater_than: 0 }
  validates :pf_admin_charge_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :pf_edli_rate,         numericality: { greater_than_or_equal_to: 0 }
  validates :esi_employee_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :esi_employer_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :esi_ceiling,       numericality: { greater_than: 0 }
  validates :week_off_pattern,  inclusion: { in: WEEK_OFF_PATTERNS }
  validates :pt_state, presence: true, if: :pt_enabled?
  validates :pt_state, inclusion: { in: SUPPORTED_PT_STATES }, allow_blank: true
end
