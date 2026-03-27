FactoryBot.define do
  factory :theme do
    name { "Simple Emoji" }
    sequence(:hugo_theme) { |n| "simple_emoji_#{n}" }
  end
end
