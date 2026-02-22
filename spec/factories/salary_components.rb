FactoryBot.define do
  factory :salary_component do
    association :tenant
    sequence(:name) { |n| "Component #{n}" }
    component_type { "earning" }
    calculation_type { "flat" }
    taxable { true }
    active { true }
    sort_order { 0 }

    trait :earning do
      component_type { "earning" }
    end

    trait :deduction do
      component_type { "deduction" }
    end

    trait :employer_contribution do
      component_type { "employer_contribution" }
    end

    trait :percentage do
      calculation_type { "percentage" }
    end

    trait :inactive do
      active { false }
    end

    trait :non_taxable do
      taxable { false }
    end
  end
end
