FactoryBot.define do
  factory :leave_balance do
    association :tenant
    association :employee
    association :leave_type
    financial_year        { LeaveBalance.current_financial_year }
    total_days            { 12 }
    used_days             { 0 }
    remaining_days        { 12 }
    carried_forward_days  { 0 }
  end
end
