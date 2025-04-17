FactoryBot.define do
  factory :user_invitation do
    email { Faker::Internet.email }
    site
    inviting_user { association(:user) }

    trait :accepted do
      accepted_at { Time.current }
    end
  end
end
