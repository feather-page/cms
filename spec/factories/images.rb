FactoryBot.define do
  factory :image do
    site
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/15x15.jpg"), 'image/jpeg') }

    trait :with_file do
      # file is already set by default, this trait exists for backward compatibility
    end
  end
end
