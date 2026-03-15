FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }

    trait :superadmin do
      super_admin { true }
    end

  end
end
