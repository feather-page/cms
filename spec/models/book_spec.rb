require "rails_helper"

RSpec.describe Book do
  describe "validations" do
    context "with valid attributes" do
      it "is valid" do
        book = build(:book)
        expect(book).to be_valid
      end
    end

    context "without title" do
      it "is not valid" do
        book = build(:book, title: nil)
        expect(book).not_to be_valid
      end
    end

    context "without author" do
      it "is not valid" do
        book = build(:book, author: nil)
        expect(book).not_to be_valid
      end
    end

    context "when reading_status is finished" do
      it "requires read_at" do
        book = build(:book, reading_status: :finished, read_at: nil)
        expect(book).not_to be_valid
        expect(book.errors[:read_at]).to be_present
      end
    end

    context "when reading_status is want_to_read" do
      it "does not require read_at" do
        book = build(:book, :want_to_read)
        expect(book).to be_valid
      end
    end

    context "when reading_status is reading" do
      it "does not require read_at" do
        book = build(:book, :reading)
        expect(book).to be_valid
      end
    end
  end

  describe "reading_status enum" do
    it "has the correct values" do
      expect(described_class.reading_statuses).to eq({
                                                       "want_to_read" => 0,
                                                       "reading" => 1,
                                                       "finished" => 2
                                                     })
    end

    it "generates prefix methods" do
      book = build(:book, reading_status: :finished)
      expect(book).to be_reading_status_finished
      expect(book).not_to be_reading_status_reading
    end
  end

  describe "scopes" do
    describe ".ordered" do
      it "orders books by read_at descending" do
        site = create(:site)
        old_book = create(:book, site:, read_at: 2.years.ago)
        new_book = create(:book, site:, read_at: 1.year.ago)

        expect(described_class.ordered).to eq([new_book, old_book])
      end
    end

    describe ".by_status" do
      it "filters books by reading status" do
        site = create(:site)
        want_to_read_book = create(:book, :want_to_read, site:)
        finished_book = create(:book, site:)

        expect(described_class.by_status(:want_to_read)).to eq([want_to_read_book])
        expect(described_class.by_status(:finished)).to eq([finished_book])
      end
    end
  end

  describe "#year" do
    it "delegates to read_at" do
      book = build(:book, read_at: Time.zone.local(2023, 6, 15))
      expect(book.year).to eq(2023)
    end

    it "returns nil when read_at is nil" do
      book = build(:book, :want_to_read)
      expect(book.year).to be_nil
    end
  end

  describe "cover_image association" do
    it "can have a cover image" do
      site = create(:site)
      book = create(:book, site:)
      image = create(:image, imageable: book, site:)

      expect(book.reload.cover_image).to eq(image)
    end

    it "destroys cover image when book is destroyed" do
      site = create(:site)
      book = create(:book, site:)
      create(:image, imageable: book, site:)

      expect { book.destroy }.to change(Image, :count).by(-1)
    end
  end
end
