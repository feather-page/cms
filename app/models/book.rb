class Book < ApplicationRecord
  belongs_to :author

  has_many :images, as: :imageable, dependent: :destroy
  has_many :bookshelves, through: :bookshelf_books

  def cover
    images.first&.file
  end

  def author_name
    author.name
  end
end
