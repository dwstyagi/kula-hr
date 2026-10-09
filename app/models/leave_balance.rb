class LeaveBalance < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :leave_type

  validates :financial_year, presence: true
  validates :total_days, :used_days, :remaining_days, :carried_forward_days,
            numericality: { greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: [ :leave_type_id, :financial_year ],
                                        message: "already has a balance for this leave type and year" }

  scope :for_year, ->(fy) { where(financial_year: fy) }
  scope :current, -> { for_year(LeaveBalance.current_financial_year) }

  def self.current_financial_year
    FinancialYear.label
  end
end
