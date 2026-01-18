class Book < ApplicationRecord
  belongs_to :site
  belongs_to :post, optional: true, dependent: :destroy
  has_one :cover_image,
          -> { where(imageable_type: "Book") },
          class_name: "Image",
          foreign_key: "imageable_id",
          dependent: :destroy,
          inverse_of: false

  enum :reading_status, { want_to_read: 0, reading: 1, finished: 2 }, prefix: true

  validates :title, presence: true
  validates :author, presence: true
  validates :read_at, presence: true, if: :reading_status_finished?
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true

  def review?
    post.present?
  end

  def review_title_suggestion
    "Review: #{title}"
  end

  scope :ordered, -> { order(read_at: :desc) }
  scope :by_status, ->(status) { where(reading_status: status) }

  delegate :year, to: :read_at, allow_nil: true
end
