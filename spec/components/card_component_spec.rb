# frozen_string_literal: true

describe CardComponent, type: :component do
  it "renders a card with content" do
    render_inline(described_class.new) { "Card content" }
    expect(page).to have_css("div.card", text: "Card content")
  end

  it "does not include hover class by default" do
    render_inline(described_class.new) { "Content" }
    expect(page).to have_no_css("div.card--hover")
  end

  it "includes hover class when hover is true" do
    render_inline(described_class.new(hover: true)) { "Content" }
    expect(page).to have_css("div.card.card--hover")
  end

  it "passes through html_options" do
    render_inline(described_class.new(id: "my-card")) { "Content" }
    expect(page).to have_css("div.card#my-card")
  end
end
