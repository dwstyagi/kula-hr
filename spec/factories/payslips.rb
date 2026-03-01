FactoryBot.define do
  factory :payslip do
    association :tenant
    association :payroll_run
    association :employee

    month              { 1 }
    year               { 2026 }
    status             { "generated" }
    gross_pay          { 50_000 }
    total_deductions   { 5_000 }
    net_pay            { 45_000 }
    employer_pf        { 1_800 }
    employer_esi       { 0 }
    total_working_days { 22 }
    paid_days          { 22 }
    lop_days           { 0 }

    trait :locked do
      status { "locked" }
    end

    trait :revised do
      status     { "revised" }
      is_revised { true }
    end

    trait :with_bank_details do
      after(:create) do |payslip|
        payslip.employee.update_columns(
          bank_name:           "HDFC Bank",
          bank_account_number: "50100123456789",
          ifsc_code:           "HDFC0001234"
        )
      end
    end

    trait :without_bank_details do
      after(:create) do |payslip|
        payslip.employee.update_columns(
          bank_account_number: nil,
          ifsc_code:           nil
        )
      end
    end
  end
end
