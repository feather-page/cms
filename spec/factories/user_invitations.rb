FactoryBot.define do
  factory :user_invitation do
    email { Faker::Internet.email }
    site
    inviting_user { association(:user) }
  end
end
