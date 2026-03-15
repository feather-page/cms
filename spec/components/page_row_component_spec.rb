# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageRowComponent, type: :component do
  let(:site) { create(:site) }
  let(:page_record) { create(:page, site: site, title: "Impressum", slug: "/impressum") }

  it "renders title and slug" do
    render_inline(described_class.new(page: page_record, site: site))
    expect(page).to have_text("Impressum")
    expect(page).to have_text("/impressum")
  end

  it "renders add-to-nav button" do
    render_inline(described_class.new(page: page_record, site: site))
    expect(page).to have_css(".card-row__action-btn--success")
  end

  it "renders edit and delete buttons" do
    render_inline(described_class.new(page: page_record, site: site))
    expect(page).to have_css(".card-row__action-btn--danger")
    expect(page).to have_css("a[title='Edit']")
  end
end
