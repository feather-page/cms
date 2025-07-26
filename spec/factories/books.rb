FactoryBot.define do
  factory :book do
    title { Faker::Lorem.sentence }
    author { Faker::Name.name }
    read_at { Faker::Time.between(from: 10.years.ago, to: Date.today) }
    site
  end
end
