describe Blocks::Renderer::Html::Book do
  let(:book_model) { create(:book, title: 'Test Book', author: 'Test Author') }
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

    context 'with a valid book' do
      it 'renders the book title' do
        expect(book_html).to include('Test Book')
      end

      it 'renders the book author' do
        expect(book_html).to include('Test Author')
      end

      it 'renders with Bootstrap classes' do
        expect(book_html).to include('d-flex')
        expect(book_html).to include('bg-body-tertiary')
        expect(book_html).to include('rounded')
      end
    end

    context 'with a book that has an emoji' do
      let(:book_model) { create(:book, emoji: '123') }

      it 'renders the emoji' do
        expect(book_html).to include('123')
        expect(book_html).to include('font-size: 1.5rem')
      end
    end

    context 'with a book that has a cover image' do
      let(:book_model) { create(:book, :with_cover) }

      it 'renders the cover image' do
        expect(book_html).to include('<img')
        expect(book_html).to include('max-height: 40px')
        expect(book_html).to include('class="rounded"')
      end
    end

    context 'when the book does not exist' do
      let(:block) do
        Blocks::Book.new(
          id: 'book123',
          book_public_id: 'nonexistent',
          title: 'Cached Title',
          author: 'Cached Author'
        )
      end

      it 'renders nothing' do
        expect(book_html.strip).to be_empty
      end
    end
  end
end
