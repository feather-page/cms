FactoryBot.define do
  factory :api_token do
    user
    name { "Test Token" }
  end
end
