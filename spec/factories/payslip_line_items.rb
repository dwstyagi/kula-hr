FactoryBot.define do
  factory :payslip_line_item do
    association :payslip

    component_name { "Basic" }
    component_type { "earning" }
    amount         { 33_333 }
    full_amount    { 33_333 }
    sort_order     { 1 }
    category       { "fixed" }

    trait :earning do
      component_type { "earning" }
    end

    trait :deduction do
      component_name { "PF" }
      component_type { "deduction" }
      amount         { 1_800 }
      full_amount    { nil }
      category       { "statutory" }
    end

    trait :prorated do
      amount      { 30_000 }
      full_amount { 33_333 }
    end
  end
end
