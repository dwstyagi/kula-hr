FactoryBot.define do
  factory :employee_salary do
    association :tenant
    association :employee
    association :salary_structure
    annual_ctc { 600_000 }
    effective_from { employee.joining_date }
    effective_to { nil }

    trait :with_history do
      effective_from { 1.year.ago.to_date }
      effective_to { Date.today }
    end
  end
end
