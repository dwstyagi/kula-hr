class PayrollSetting < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  WEEK_OFF_PATTERNS = %w[all_saturdays_sundays alternate_saturdays_sundays only_sundays].freeze

  validates :pf_employee_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :pf_employer_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :pf_ceiling, numericality: { greater_than_or_equal_to: 0 }
  validates :esi_employee_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :esi_employer_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :esi_ceiling, numericality: { greater_than_or_equal_to: 0 }
  validates :week_off_pattern, inclusion: { in: WEEK_OFF_PATTERNS }
end
