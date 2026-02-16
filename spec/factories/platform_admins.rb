FactoryBot.define do
  factory :platform_admin do
    first_name { "Platform" }
    last_name { "Admin" }
    sequence(:email) { |n| "admin#{n}@kulahr.com" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
