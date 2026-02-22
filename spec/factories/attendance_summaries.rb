FactoryBot.define do
  factory :attendance_summary do
    association :tenant
    association :employee
    month  { Date.today.month }
    year   { Date.today.year }
    status { :draft }
    total_working_days  { 22 }
    days_present        { 22 }
    approved_leaves     { 0 }
    lop_leaves          { 0 }
    half_days           { 0 }
    # unapproved_absences, lop_days, paid_days are derived by before_save callback

    trait :with_lop do
      days_present { 20 }   # 2 unapproved absences → lop_days = 2
    end

    trait :locked do
      status { :locked }
    end
  end
end
