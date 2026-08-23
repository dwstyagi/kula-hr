FactoryBot.define do
  factory :off_cycle_payroll_entry do
    association :tenant
    association :payroll_run
    association :employee
    gross_amount { 25_000 }
    tds_amount { 2_500 }
  end
end
