FactoryBot.define do
  factory :salary_structure_component do
    association :salary_structure
    association :salary_component
    value { 10.0 }
  end
end
