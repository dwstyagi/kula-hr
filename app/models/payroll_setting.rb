class PayrollSetting < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant

  validates :pf_employee_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :pf_employer_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :pf_ceiling, numericality: { greater_than_or_equal_to: 0 }
  validates :esi_employee_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :esi_employer_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :esi_ceiling, numericality: { greater_than_or_equal_to: 0 }
end
