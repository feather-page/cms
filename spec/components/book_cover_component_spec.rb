# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookCoverComponent, type: :component do
  let(:site) { create(:site) }

  describe "finished book with rating" do
    let(:book) { create(:book, site: site, title: "Othello", author: "William Shakespeare", rating: 4, reading_status: :finished) }

    it "renders title and author" do
      render_inline(described_class.new(book: book))
      expect(page).to have_text("Othello")
      expect(page).to have_text("William Shakespeare")
    end

    it "renders star rating" do
      render_inline(described_class.new(book: book))
      expect(page).to have_css(".book-cover__rating", text: "★★★★☆")
    end

    it "links to edit path" do
      render_inline(described_class.new(book: book))
      expect(page).to have_css("a.book-cover[href*='/books/']")
    end
  end

  describe "book without cover" do
    let(:book) { create(:book, site: site, emoji: "📕", reading_status: :finished) }

    it "renders emoji fallback" do
      render_inline(described_class.new(book: book))
      expect(page).to have_css(".book-cover__emoji", text: "📕")
    end
  end

  describe "want-to-read book" do
    let(:book) { create(:book, :want_to_read, site: site) }

    it "does not render rating" do
      render_inline(described_class.new(book: book))
      expect(page).not_to have_css(".book-cover__rating")
    end
  end

  describe "currently reading book" do
    let(:book) { create(:book, :reading, site: site) }

    it "does not render rating" do
      render_inline(described_class.new(book: book))
      expect(page).not_to have_css(".book-cover__rating")
    end
  end
end
