FactoryBot.define do
  factory :comp_off_request do
    association :tenant
    association :employee
    worked_date { 1.week.ago.to_date.then { |d| d.saturday? || d.sunday? ? d : d - d.wday } }
    reason      { "Worked on a holiday" }
    status      { :pending }

    trait :approved do
      status      { :approved }
      approved_at { Time.current }
      expiry_date { 7.days.from_now.to_date }
    end

    trait :rejected do
      status           { :rejected }
      rejection_reason { "Not eligible" }
    end
  end
end
