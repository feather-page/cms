class Bookshelf < ApplicationRecord
  belongs_to :site

  has_many :bookshelf_books
  has_many :books, through: :bookshelf_books

  validates :name, presence: true, uniqueness: { scope: :site }
end
