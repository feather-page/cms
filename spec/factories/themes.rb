# frozen_string_literal: true

FactoryBot.define do
  factory :theme do
    sequence(:name) { |n| "Theme #{n}" }
    description { "A test theme" }
    sequence(:hugo_theme) { |n| "test_theme_#{n}" }

    trait :simple_emoji do
      name { "Simple Emoji" }
      description { "A playful simple theme that supports emoji." }
      hugo_theme { "simple_emoji" }
    end
  end
end
