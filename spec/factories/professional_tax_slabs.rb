FactoryBot.define do
  factory :professional_tax_slab do
    association :tenant
    state       { "maharashtra" }
    salary_from { 0 }
    salary_to   { 7_500 }
    tax_amount  { 0 }
    month       { nil }

    # Maharashtra slabs
    trait :mh_low do        # 0 – 7,500 → ₹0
      state { "maharashtra" }; salary_from { 0 };      salary_to { 7_500 };   tax_amount { 0 };   month { nil }
    end

    trait :mh_mid do        # 7,501 – 10,000 → ₹175
      state { "maharashtra" }; salary_from { 7_501 };  salary_to { 10_000 };  tax_amount { 175 }; month { nil }
    end

    trait :mh_high do       # 10,001+ → ₹200 (non-Feb)
      state { "maharashtra" }; salary_from { 10_001 }; salary_to { 999_999 }; tax_amount { 200 }; month { nil }
    end

    trait :mh_feb do        # 10,001+ → ₹300 (February only)
      state { "maharashtra" }; salary_from { 10_001 }; salary_to { 999_999 }; tax_amount { 300 }; month { "february" }
    end

    # Karnataka slabs
    trait :ka_low do        # 0 – 15,000 → ₹0
      state { "karnataka" };   salary_from { 0 };       salary_to { 15_000 };  tax_amount { 0 };   month { nil }
    end

    trait :ka_high do       # 15,001+ → ₹200
      state { "karnataka" };   salary_from { 15_001 };  salary_to { 999_999 }; tax_amount { 200 }; month { nil }
    end
  end
end
