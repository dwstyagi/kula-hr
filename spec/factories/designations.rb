FactoryBot.define do
  factory :designation do
    association :tenant
    sequence(:name) { |n| "Designation #{n}" }
  end
end
