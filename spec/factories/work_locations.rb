FactoryBot.define do
  factory :work_location do
    association :tenant
    sequence(:name) { |n| "Location #{n}" }
    state      { "Maharashtra" }
    is_active  { true }

    trait :inactive do
      is_active { false }
    end
  end
end
