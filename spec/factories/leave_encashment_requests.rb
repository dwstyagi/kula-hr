FactoryBot.define do
  factory :leave_encashment_request do
    association :tenant
    association :employee
    association :leave_type, :earned
    financial_year { LeaveBalance.current_financial_year }
    number_of_days { 6 }
    status         { :pending }

    trait :approved do
      status            { :approved }
      encashment_amount { 3000.00 }
    end

    trait :rejected do
      status           { :rejected }
      rejection_reason { "Not eligible" }
    end
  end
end
