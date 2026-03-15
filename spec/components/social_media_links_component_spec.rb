require "rails_helper"

describe SocialMediaLinksComponent, type: :component do
  it 'renders the icon, name and url' do
    social_media_link = create(:social_media_link, name: 'Instagram', icon: :instagram, url: 'https://instagram.com/example')

    render_inline(described_class.new(social_media_links: [social_media_link]))

    expect(page).to have_css('svg.icon')
    expect(page).to have_text('Instagram')
    expect(page).to have_text('https://instagram.com/example')
  end
end
