describe Blocks::Book do
  let(:book_model) { create(:book, title: 'Test Book', author: 'Test Author', emoji: nil) }
  let(:editor_js_hash) do
    {
      'id' => 'book123',
      'type' => 'book',
      'data' => {
        'book_public_id' => book_model.public_id,
        'title' => 'Test Book',
        'author' => 'Test Author',
        'cover_url' => nil,
        'emoji' => nil
      }
    }
  end

  describe '.from_editor_js' do
    it 'returns a new instance of the class' do
      book_block = described_class.from_editor_js(editor_js_hash)

      expect(book_block.id).to eq('book123')
      expect(book_block.type).to eq('book')
      expect(book_block.book_public_id).to eq(book_model.public_id)
      expect(book_block.title).to eq('Test Book')
      expect(book_block.author).to eq('Test Author')
    end
  end

  describe '#to_editor_js' do
    it 'returns the right editor js hash' do
      book_block = described_class.from_editor_js(editor_js_hash)

      expect(book_block.to_editor_js).to eq(editor_js_hash)
    end

    context 'when book data has changed' do
      it 'returns fresh data from the book model' do
        book_block = described_class.from_editor_js(editor_js_hash)
        book_model.update!(title: 'Updated Title', author: 'Updated Author')

        result = book_block.to_editor_js
        expect(result['data']['title']).to eq('Updated Title')
        expect(result['data']['author']).to eq('Updated Author')
      end
    end

    context 'when book no longer exists' do
      it 'falls back to cached data' do
        book_block = described_class.from_editor_js(editor_js_hash)
        book_model.destroy

        result = book_block.to_editor_js
        expect(result['data']['title']).to eq('Test Book')
        expect(result['data']['author']).to eq('Test Author')
      end
    end
  end

  describe '#book' do
    it 'returns the associated book model' do
      book_block = described_class.from_editor_js(editor_js_hash)

      expect(book_block.book).to eq(book_model)
    end

    it 'returns nil when book does not exist' do
      editor_js_hash['data']['book_public_id'] = 'nonexistent'
      book_block = described_class.from_editor_js(editor_js_hash)

      expect(book_block.book).to be_nil
    end

    it 'memoizes the book lookup' do
      book_block = described_class.from_editor_js(editor_js_hash)

      expect(Book).to receive(:find_by).once.and_call_original

      2.times { book_block.book }
    end
  end
end
