FactoryBot.define do
  factory :project do
    title { "#{Faker::Company.name} #{%w[Refactoring Migration Development Optimization].sample}" }
    company { Faker::Company.name }
    period { "#{Faker::Date.between(from: 5.years.ago, to: 2.years.ago).strftime('%B %Y')} - #{Faker::Date.between(from: 2.years.ago, to: Time.zone.today).strftime('%B %Y')}" }
    started_at { Faker::Date.between(from: 5.years.ago, to: 2.years.ago) }
    ended_at { Faker::Date.between(from: 2.years.ago, to: Time.zone.today) }
    status { :completed }
    role { ["Senior Developer", "Lead Engineer", "Backend Developer", "Full Stack Developer"].sample }
    short_description { Faker::Lorem.sentence(word_count: 20) }
    content { nil }
    project_type { :professional }
    links { [{ "label" => "Website", "url" => Faker::Internet.url }] }
    emoji { ["🚀", "💻", "⚙️", "📱", "🔧"].sample }
    slug { Faker::Lorem.sentence.parameterize }
    site

    trait :ongoing do
      status { :ongoing }
      ended_at { nil }
    end

    trait :paused do
      status { :paused }
    end

    trait :abandoned do
      status { :abandoned }
    end

    trait :personal do
      project_type { :personal }
      company { nil }
    end

    trait :open_source do
      project_type { :open_source }
      company { nil }
    end

    trait :freelance do
      project_type { :freelance }
    end

    trait :with_header_image do
      after(:create) do |project|
        create(:image, imageable: project, site: project.site)
        project.update!(header_image: project.site.images.last)
      end
    end

    trait :with_detailed_content do
      after(:create) do |project|
        project.update!(content: [
                          {
                            "type" => "header",
                            "data" => { "text" => "Project Overview", "level" => 2 }
                          },
                          {
                            "type" => "paragraph",
                            "data" => { "text" => Faker::Lorem.paragraph(sentence_count: 5) }
                          }
                        ])
      end
    end
  end
end
