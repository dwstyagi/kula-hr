FactoryBot.define do
  factory :payroll_setting do
    association :tenant
    pf_enabled           { true }
    pf_employee_rate     { 12.0 }
    pf_employer_rate     { 12.0 }
    pf_wage_ceiling      { 15_000 }
    pf_include_da        { true }
    pf_admin_charge_rate { 0.50 }
    pf_edli_rate         { 0.50 }
    esi_enabled          { true }
    esi_employee_rate    { 0.75 }
    esi_employer_rate    { 3.25 }
    esi_ceiling          { 21_000 }
    pt_enabled           { true }
    pt_state             { "maharashtra" }
    tds_enabled          { true }
    week_off_pattern     { "all_saturdays_sundays" }

    trait :no_pf do
      pf_enabled { false }
    end

    trait :no_esi do
      esi_enabled { false }
    end

    trait :no_pt do
      pt_enabled { false }
      pt_state   { nil }
    end

    trait :karnataka do
      pt_state { "karnataka" }
    end
  end
end
