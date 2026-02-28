FactoryBot.define do
  factory :investment_declaration do
    association :tenant
    association :tax_declaration

    section         { "80C" }
    description     { "PPF" }
    declared_amount { 50_000 }

    trait :section_80c do
      section { "80C" }; description { "PPF" }; declared_amount { 50_000 }
    end

    trait :section_80d do
      section { "80D" }; description { "Health Insurance (Self)" }; declared_amount { 15_000 }
    end

    trait :section_80ccd1b do
      section { "80CCD1B" }; description { "NPS Contribution" }; declared_amount { 50_000 }
    end

    trait :section_24b do
      section { "24b" }; description { "Home Loan Interest" }; declared_amount { 120_000 }
    end
  end
end
