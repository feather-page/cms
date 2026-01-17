require "rails_helper"

describe "Book features" do
  describe "creating a new book" do
    it "creates a new book with finished status" do
      as_user do |user|
        site = create(:site, users: [user])

        visit new_site_book_path(site)

        fill_in "Title", with: "My Book"
        fill_in "Author", with: "Foo Bar"
        fill_in "Emoji", with: "📕"
        fill_in "Read at", with: "2020-01-01"
        select "Finished Reading", from: "Reading Status"

        expect do
          click_on "Create Book"
        end.to change { site.books.count }.by(1)

        created_book = site.books.last
        expect(created_book.title).to eq("My Book")
        expect(created_book.author).to eq("Foo Bar")
        expect(created_book.read_at.to_date).to eq(Date.new(2020, 1, 1))
        expect(created_book).to be_reading_status_finished
      end
    end

    it "creates a want to read book without read_at date" do
      as_user do |user|
        site = create(:site, users: [user])

        visit new_site_book_path(site)

        fill_in "Title", with: "Future Reading"
        fill_in "Author", with: "Someone"
        select "Want to Read", from: "Reading Status"

        expect do
          click_on "Create Book"
        end.to change { site.books.count }.by(1)

        created_book = site.books.last
        expect(created_book.title).to eq("Future Reading")
        expect(created_book.read_at).to be_nil
        expect(created_book).to be_reading_status_want_to_read
      end
    end
  end

  describe "editing a book" do
    it "edits a book" do
      as_user do |user|
        site = create(:site, users: [user])
        book = create(:book, site:)

        visit edit_book_path(book)

        fill_in "Title", with: "New title"

        click_on "Update Book"

        expect(book.reload.title).to eq("New title")
      end
    end

    it "changes reading status" do
      as_user do |user|
        site = create(:site, users: [user])
        book = create(:book, :want_to_read, site:)

        visit edit_book_path(book)

        select "Currently Reading", from: "Reading Status"
        click_on "Update Book"

        expect(book.reload).to be_reading_status_reading
      end
    end
  end

  describe "deleting a book" do
    it "deletes a book" do
      as_user do |user|
        site = create(:site, users: [user])
        book = create(:book, site:)

        visit site_books_path(site)

        accept_confirm do
          click_link("Delete")
        end

        expect(Book.find_by(id: book.id)).to be_nil
      end
    end
  end

  describe "bookshelf tabs" do
    it "filters books by reading status" do
      as_user do |user|
        site = create(:site, users: [user])
        create(:book, site:, title: "Finished Book")
        create(:book, :want_to_read, site:, title: "Want to Read Book")

        visit site_books_path(site)

        expect(page).to have_content("Finished Book")
        expect(page).to have_no_content("Want to Read Book")

        click_link "Want to Read"

        expect(page).to have_content("Want to Read Book")
        expect(page).to have_no_content("Finished Book")
      end
    end
  end
end
