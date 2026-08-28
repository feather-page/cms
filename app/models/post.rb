class Post < ApplicationRecord
  include Editable
  include Sluggable
  include Taggable

  belongs_to :site
  has_one :book, dependent: :nullify

  before_validation :set_publish_at

  validates :slug, uniqueness: { scope: :site_id }, allow_blank: true
  validates :emoji, emoji: true

  scope :latest, -> { order(publish_at: :desc) }
  scope :published, lambda {
    where(draft: false).where(publish_at: (..Time.current))
  }

  private

  def set_publish_at
    self.publish_at ||= Time.current
  end
end
