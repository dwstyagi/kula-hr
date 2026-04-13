FactoryBot.define do
  factory :holiday do
    association :tenant
    sequence(:name) { |n| "Holiday #{n}" }
    date      { Date.today + 30 }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
