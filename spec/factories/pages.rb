FactoryBot.define do
  factory :page do
    title { Faker::Lorem.sentence }
    content { nil }
    site
    slug { Faker::Lorem.sentence.parameterize }

    trait :tagged do
      tags { "travel, photos" }
    end

    trait :books do
      page_type { 'books' }
    end

    trait :with_thumbnail_image do
      after(:create) do |page|
        image = create(:image, imageable: page, site: page.site)
        page.update!(thumbnail_image: image)
      end
    end
  end
end
