class BookshelfBook < ApplicationRecord
  delegate :title, :cover, :author_name, to: :book
  belongs_to :book
  belongs_to :bookshelf
end
