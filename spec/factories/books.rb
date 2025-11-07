FactoryBot.define do
  factory :book do
    title { Faker::Lorem.sentence }
    author { Faker::Name.name }
    read_at { Faker::Time.between(from: 10.years.ago, to: Time.zone.today) }
    site
  end
end
