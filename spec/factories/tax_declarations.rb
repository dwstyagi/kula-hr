FactoryBot.define do
  factory :tax_declaration do
    association :tenant
    association :employee

    financial_year { "2025-26" }
    regime         { :new_regime }
    status         { :draft }
    claiming_hra   { false }
    monthly_rent   { 0 }
    home_loan_interest  { 0 }
    home_loan_principal { 0 }

    trait :old_regime do
      regime { :old_regime }
    end

    trait :new_regime do
      regime { :new_regime }
    end

    trait :submitted do
      status { :submitted }
    end

    trait :verified do
      status { :verified }
    end

    trait :with_hra do
      regime       { :old_regime }
      claiming_hra { true }
      monthly_rent { 15_000 }
      landlord_name { "Ramesh Kumar" }
      rental_city  { "metro" }
    end

    trait :with_home_loan do
      regime              { :old_regime }
      home_loan_interest  { 120_000 }
      home_loan_principal { 80_000 }
    end
  end
end
