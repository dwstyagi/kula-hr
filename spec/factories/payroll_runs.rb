FactoryBot.define do
  factory :payroll_run do
    association :tenant
    association :initiated_by, factory: :user

    month               { 1 }
    year                { 2026 }
    status              { "draft" }
    total_employees     { 0 }
    processed_employees { 0 }
    total_gross         { 0 }
    total_deductions    { 0 }
    total_net_pay       { 0 }
    total_employer_cost { 0 }

    # Bypass attendance_must_be_locked (on: :create) — tested explicitly in model spec
    to_create { |instance| instance.save!(validate: false) }

    trait :processing do
      status { "processing" }
    end

    trait :processed do
      status              { "processed" }
      processed_employees { 3 }
      total_gross         { 150_000 }
      total_deductions    { 15_000 }
      total_net_pay       { 135_000 }
      total_employer_cost { 6_000 }
    end

    trait :under_review do
      status              { "under_review" }
      processed_employees { 3 }
      total_gross         { 150_000 }
      total_deductions    { 15_000 }
      total_net_pay       { 135_000 }
      total_employer_cost { 6_000 }
    end

    trait :approved do
      status              { "approved" }
      processed_employees { 3 }
      total_gross         { 150_000 }
      total_deductions    { 15_000 }
      total_net_pay       { 135_000 }
      total_employer_cost { 6_000 }
    end

    trait :rejected do
      status           { "rejected" }
      rejection_reason { "Numbers look incorrect." }
    end

    trait :paid do
      status              { "paid" }
      processed_employees { 3 }
      total_gross         { 150_000 }
      total_deductions    { 15_000 }
      total_net_pay       { 135_000 }
      total_employer_cost { 6_000 }
    end
  end
end
