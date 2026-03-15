# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookshelfComponent, type: :component do
  let(:site) { create(:site) }

  it "shows currently reading section" do
    create(:book, :reading, site: site, title: "Current Book")
    render_inline(described_class.new(books: site.books, site: site))
    expect(page).to have_text("Currently Reading")
    expect(page).to have_text("Current Book")
  end

  it "shows want to read section" do
    create(:book, :want_to_read, site: site, title: "Future Book")
    render_inline(described_class.new(books: site.books, site: site))
    expect(page).to have_text("Want to Read")
    expect(page).to have_text("Future Book")
  end

  it "groups finished books by year" do
    create(:book, site: site, title: "Old Book", read_at: Date.new(2025, 6, 15), reading_status: :finished)
    create(:book, site: site, title: "New Book", read_at: Date.new(2026, 1, 10), reading_status: :finished)
    render_inline(described_class.new(books: site.books, site: site))
    expect(page).to have_text("2026")
    expect(page).to have_text("2025")
  end

  it "shows book count per year" do
    create_list(:book, 3, site: site, read_at: Date.new(2026, 3, 1), reading_status: :finished)
    render_inline(described_class.new(books: site.books, site: site))
    expect(page).to have_text("3 Bücher")
  end

  it "shows empty state when no books" do
    render_inline(described_class.new(books: site.books, site: site))
    expect(page).to have_text("Dein Bücherregal ist leer")
  end

  it "hides currently reading section when none" do
    create(:book, site: site, reading_status: :finished)
    render_inline(described_class.new(books: site.books, site: site))
    expect(page).not_to have_text("Currently Reading")
  end
end
