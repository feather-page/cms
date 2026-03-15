# frozen_string_literal: true

describe PageLayoutComponent, type: :component do
  it "renders a page layout with content" do
    render_inline(described_class.new) { "Page body" }
    expect(page).to have_css(".page-layout")
    expect(page).to have_css(".page-layout__content", text: "Page body")
  end

  it "renders a page header when title is given" do
    render_inline(described_class.new(title: "Dashboard")) { "Content" }
    expect(page).to have_css(".page-header__title", text: "Dashboard")
  end

  it "does not render a page header when no title" do
    render_inline(described_class.new) { "Content" }
    expect(page).to have_no_css(".page-header")
  end
end
