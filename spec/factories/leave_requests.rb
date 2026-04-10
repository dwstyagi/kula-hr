FactoryBot.define do
  factory :leave_request do
    association :tenant
    association :employee
    association :leave_type
    from_date { Date.today + 7 }
    to_date   { Date.today + 7 }
    reason    { "Personal reasons" }
    status    { :pending }

    # Compute number_of_days after other attributes are set (since save(validate: false)
    # skips before_validation callbacks that normally compute this field)
    after(:build) do |lr|
      if lr.number_of_days.nil? && lr.from_date && lr.to_date && lr.to_date >= lr.from_date
        pattern = lr.employee&.tenant&.payroll_setting&.week_off_pattern || "all_saturdays_sundays"
        lr.number_of_days = (lr.from_date..lr.to_date).count { |d| Attendance::WorkingDaysCalculator.working_day?(d, pattern) }
      end
    end

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status       { :rejected }
      rejection_reason { "Insufficient notice" }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :multi_day do
      from_date { Date.today + 7 }
      to_date   { Date.today + 11 }   # Mon–Fri → 5 business days
    end
  end
end
