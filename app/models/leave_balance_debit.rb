class LeaveBalanceDebit < ApplicationRecord
  belongs_to :leave_request
  belongs_to :leave_balance
  validates :number_of_days, numericality: { greater_than: 0 }
end
