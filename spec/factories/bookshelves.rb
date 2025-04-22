FactoryBot.define do
  factory :bookshelf do
    name { Faker::Lorem.word }
    site
  end
end
