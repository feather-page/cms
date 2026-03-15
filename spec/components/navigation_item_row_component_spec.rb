# frozen_string_literal: true

require "rails_helper"

RSpec.describe NavigationItemRowComponent, type: :component do
  let(:site) { create(:site) }
  let(:page_record) { create(:page, site: site, title: "About", slug: "/about") }
  let(:navigation) { site.main_navigation }
  let(:item) { create(:navigation_item, navigation: navigation, page: page_record) }

  it "renders title and slug" do
    render_inline(described_class.new(item: item, site: site))
    expect(page).to have_text("About")
    expect(page).to have_text("/about")
  end

  it "renders up and down arrows" do
    render_inline(described_class.new(item: item, site: site))
    expect(page).to have_css(".card-row__action-btn", minimum: 4)
  end

  it "renders remove button" do
    render_inline(described_class.new(item: item, site: site))
    expect(page).to have_css(".card-row__action-btn--danger")
  end
end
