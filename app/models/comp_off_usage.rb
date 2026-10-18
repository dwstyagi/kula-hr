class CompOffUsage < ApplicationRecord
  belongs_to :comp_off_request
  belongs_to :leave_request
  validates :number_of_days, numericality: { greater_than: 0 }
end
