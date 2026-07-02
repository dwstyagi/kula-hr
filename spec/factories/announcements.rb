FactoryBot.define do
  factory :announcement do
    association :tenant
    association :author, factory: :user
    sequence(:title) { |n| "Announcement #{n}" }
    body { "This is an important company announcement." }
    published { false }

    trait :published do
      published { true }
      published_at { Time.current }
    end
  end
end
