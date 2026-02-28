FactoryBot.define do
  factory :employee do
    association :tenant
    first_name        { Faker::Name.first_name }
    last_name         { Faker::Name.last_name }
    sequence(:email)  { |n| "employee#{n}@example.com" }
    joining_date      { 1.year.ago.to_date }
    employment_status { "active" }
    pf_applicable     { true }
    pf_on_full_basic  { false }
    pt_applicable     { true }

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

    trait :pf_opted_out do
      pf_applicable { false }
    end

    trait :pf_on_full_basic do
      pf_on_full_basic { true }
    end

    trait :pt_opted_out do
      pt_applicable { false }
    end
  end
end
