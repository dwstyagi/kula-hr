FactoryBot.define do
  factory :employee do
    association :tenant
    first_name        { Faker::Name.first_name }
    last_name         { Faker::Name.last_name }
    sequence(:email)  { |n| "employee#{n}@example.com" }
    joining_date      { 1.year.ago.to_date }
    employment_status { "active" }

    trait :with_user do
      association :user
    end

    trait :with_department do
      association :department
    end

    trait :with_designation do
      association :designation
    end

    trait :probation do
      employment_status { "probation" }
    end

    trait :resigned do
      employment_status { "resigned" }
    end
  end
end
