FactoryBot.define do
  factory :payroll_setting do
    association :tenant
    pf_employee_rate { 12.0 }
    pf_employer_rate { 12.0 }
    pf_ceiling { 15_000 }
    esi_employee_rate { 0.75 }
    esi_employer_rate { 3.25 }
    esi_ceiling { 21_000 }
    state { "Maharashtra" }
  end
end
