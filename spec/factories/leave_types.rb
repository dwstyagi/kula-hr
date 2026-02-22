FactoryBot.define do
  factory :leave_type do
    association :tenant
    sequence(:name) { |n| "Leave Type #{n}" }
    sequence(:code) { |n| "LT#{n}" }
    annual_quota    { 12 }
    carry_forward   { false }
    max_carry_forward { 0 }
    is_paid         { true }
    is_active       { true }

    trait :casual do
      name { "Casual Leave" }
      code { "CL" }
      annual_quota { 12 }
    end

    trait :sick do
      name { "Sick Leave" }
      code { "SL" }
      annual_quota { 6 }
    end

    trait :earned do
      name  { "Earned Leave" }
      code  { "EL" }
      annual_quota  { 15 }
      carry_forward { true }
      max_carry_forward { 30 }
    end

    trait :lop do
      name  { "Loss of Pay" }
      code  { "LOP" }
      annual_quota { 0 }
      is_paid { false }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
