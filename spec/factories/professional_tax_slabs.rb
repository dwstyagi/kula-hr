FactoryBot.define do
  factory :professional_tax_slab do
    association :tenant
    state { "Maharashtra" }
    salary_from { 0 }
    salary_to { 7_500 }
    tax_amount { 0 }
    month { nil }
  end
end
