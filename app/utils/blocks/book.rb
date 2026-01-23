module Blocks
  class Book < Base
    keyword :book_public_id
    keyword :title, default: nil
    keyword :author, default: nil
    keyword :cover_url, default: nil
    keyword :emoji, default: nil

    def self.from_editor_js(hash)
      data = hash['data']
      new(
        id: hash['id'],
        book_public_id: data['book_public_id'],
        title: data['title'],
        author: data['author'],
        cover_url: data['cover_url'],
        emoji: data['emoji']
      )
    end

    def editor_js_data
      {
        'book_public_id' => book_public_id,
        'title' => book&.title || title,
        'author' => book&.author || author,
        'cover_url' => cover_url,
        'emoji' => book&.emoji || emoji
      }
    end

    def book
      return @book if defined?(@book)

      @book = ::Book.find_by(public_id: book_public_id)
    end
  end
end
