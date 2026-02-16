FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    trait :super_admin do
      after(:create) { |user| user.assign_role(:super_admin) }
    end

    trait :hr_admin do
      after(:create) { |user| user.assign_role(:hr_admin) }
    end

    trait :employee do
      after(:create) { |user| user.assign_role(:employee) }
    end
  end
end
