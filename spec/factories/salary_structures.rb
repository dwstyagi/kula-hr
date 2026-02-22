FactoryBot.define do
  factory :salary_structure do
    association :tenant
    sequence(:name) { |n| "Structure #{n}" }
    active { true }

    trait :inactive do
      active { false }
    end
  end
end
