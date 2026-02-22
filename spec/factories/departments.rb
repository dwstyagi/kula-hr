FactoryBot.define do
  factory :department do
    association :tenant
    sequence(:name) { |n| "Department #{n}" }
  end
end
