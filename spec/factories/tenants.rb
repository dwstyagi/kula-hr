FactoryBot.define do
  factory :tenant do
    name { Faker::Company.name }
    sequence(:subdomain) { |n| "tenant#{n}" }
    state { "Maharashtra" }
    status { "trial" }

    trait :active do
      status { "active" }
    end

    trait :suspended do
      status { "suspended" }
    end

    trait :with_gstin do
      gstin { "27AABCU9603R1ZM" }
    end

    trait :with_pan do
      pan { "AABCU9603R" }
    end
  end
end
