FactoryBot.define do
  factory :page do
    title { Faker::Lorem.sentence }
    content { nil }
    site
    slug { Faker::Lorem.sentence.parameterize }

    trait :books do
      page_type { 'books' }
    end
  end
end
