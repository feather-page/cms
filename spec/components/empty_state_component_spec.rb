# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  it "renders icon and message" do
    render_inline(described_class.new(icon: "files", message: "Nothing here"))
    expect(page).to have_css(".empty-state")
    expect(page).to have_css(".empty-state__icon svg.icon")
    expect(page).to have_css(".empty-state__message", text: "Nothing here")
  end

  it "does not render a CTA button without action params" do
    render_inline(described_class.new(icon: "files", message: "Nothing here"))
    expect(page).to have_no_css("a.btn")
  end

  it "renders a CTA button when action_label and action_href are provided" do
    render_inline(described_class.new(
      icon: "file-plus",
      message: "No posts",
      action_label: "Create Post",
      action_href: "/posts/new"
    ))
    expect(page).to have_css('a.btn[href="/posts/new"]', text: "Create Post")
  end

  it "renders with emoji instead of icon" do
    render_inline(described_class.new(emoji: "✏️", message: "Noch keine Blogposts"))
    expect(page).to have_css(".empty-state__emoji", text: "✏️")
    expect(page).to have_text("Noch keine Blogposts")
  end

  it "renders subtitle when provided" do
    render_inline(described_class.new(
      emoji: "📚",
      message: "Dein Bücherregal ist leer",
      subtitle: "Füge dein erstes Buch hinzu.",
      action_label: "Neues Buch",
      action_href: "/books/new"
    ))
    expect(page).to have_css(".empty-state__subtitle", text: "Füge dein erstes Buch hinzu.")
  end

  it "does not render subtitle element when not provided" do
    render_inline(described_class.new(icon: "file", message: "Empty"))
    expect(page).to have_no_css(".empty-state__subtitle")
  end
end
