FactoryBot.define do
  factory :book do
    title { Faker::Book.title }
    author { Faker::Book.author }
    read_at { Faker::Time.between(from: 10.years.ago, to: Time.zone.today) }
    reading_status { :finished }
    site

    trait :want_to_read do
      reading_status { :want_to_read }
      read_at { nil }
    end

    trait :reading do
      reading_status { :reading }
      read_at { nil }
    end

    trait :with_cover do
      after(:create) do |book|
        create(:image, imageable: book, site: book.site)
      end
    end

    trait :with_isbn do
      isbn { Faker::Barcode.isbn }
    end
  end
end
