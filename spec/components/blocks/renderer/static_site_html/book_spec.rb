describe Blocks::Renderer::StaticSiteHtml::Book do
  let(:book_model) { create(:book, :with_cover, title: 'Test Book', author: 'Test Author') }
  let(:block) do
    Blocks::Book.new(
      id: 'book123',
      book_public_id: book_model.public_id,
      title: book_model.title,
      author: book_model.author
    )
  end

  describe '#to_html' do
    let(:book_html) { described_class.new(block).to_html }

    context 'with a book that has a cover image' do
      it 'renders the static site cover image path' do
        cover_image = book_model.cover_image
        expect(book_html).to include("/images/#{cover_image.public_id}/mobile_x1.webp")
      end

      it 'renders the book title as alt text' do
        expect(book_html).to include("alt=\"#{book_model.title}\"")
      end

      it 'renders the book-cover class' do
        expect(book_html).to include('class="book-cover"')
      end
    end

    context 'with a book that has an emoji but no cover' do
      let(:book_model) { create(:book, emoji: '456') }

      it 'renders the emoji with book-emoji class' do
        expect(book_html).to include('456')
        expect(book_html).to include('class="book-emoji"')
        expect(book_html).not_to include('<img')
      end
    end

    context 'with a valid book' do
      it 'renders the book title with book-title class' do
        expect(book_html).to include('Test Book')
        expect(book_html).to include('class="book-title"')
      end

      it 'renders the book author with book-author class' do
        expect(book_html).to include('Test Author')
        expect(book_html).to include('class="book-author"')
      end

      it 'renders the book-card container with detail modifier' do
        expect(book_html).to include('class="book-card book-card--detail"')
      end

      it 'renders the book-card-header container' do
        expect(book_html).to include('class="book-card-header"')
      end

      it 'renders the book-info container' do
        expect(book_html).to include('class="book-info"')
      end
    end
  end
end
