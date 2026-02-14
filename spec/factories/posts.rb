FactoryBot.define do
  factory :post do
    sequence(:slug) { |n| "/#{Faker::Internet.slug(glue: '-')}-#{n}" }
    title { Faker::Lorem.sentence }
    content { nil }
    site

    trait :tagged do
      tags { "ruby, rails, web" }
    end

    trait :with_thumbnail_image do
      after(:create) do |post|
        image = create(:image, imageable: post, site: post.site)
        post.update!(thumbnail_image: image)
      end
    end
  end
end
