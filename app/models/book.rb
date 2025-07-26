class Book < ApplicationRecord
  belongs_to :site

  validates :title, presence: true
  validates :author, presence: true
  validates :read_at, presence: true

  scope :ordered, -> { order(read_at: :desc) }
end
