# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreadcrumbComponent, type: :component do
  it "renders breadcrumb items with links" do
    render_inline(described_class.new(items: [
      ["Blogposts", "/sites/1/posts"],
      ["Edit Post"]
    ]))

    expect(page).to have_link("Blogposts", href: "/sites/1/posts")
    expect(page).to have_text("Edit Post")
    expect(page).to have_css(".breadcrumb__separator", text: "›")
  end

  it "renders last item as text without link" do
    render_inline(described_class.new(items: [
      ["Blogposts", "/sites/1/posts"],
      ["Edit Post"]
    ]))

    expect(page).not_to have_link("Edit Post")
  end

  it "renders single item without separator" do
    render_inline(described_class.new(items: [["Site"]]))

    expect(page).to have_text("Site")
    expect(page).not_to have_css(".breadcrumb__separator")
  end
end
