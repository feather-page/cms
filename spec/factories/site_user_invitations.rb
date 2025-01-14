FactoryBot.define do
  factory :site_user_invitation do
    email { Faker::Internet.email }
    site
    inviting_user { association(:user) }
  end
end
