FactoryBot.define do
  factory :full_and_final_settlement do
    tenant
    employee { association(:employee, tenant: tenant) }
    payroll_run do
      association(
        :payroll_run,
        tenant: tenant,
        run_type: "full_and_final",
        title: "Full & Final Settlement",
        payment_date: Date.new(2026, 8, 31),
        month: 8,
        year: 2026
      )
    end
    last_working_date { Date.new(2026, 8, 15) }
    salary_days { 15 }
    earned_salary { 30_000 }
    leave_encashment { 5_000 }
  end
end
