class Page < ApplicationRecord
  include Editable

  enum :page_type, { default: 0, books: 1 }, prefix: true

  attribute :add_to_navigation, :boolean, default: false
  has_many :navigation_items, dependent: :destroy

  scope :not_in_navigation, -> { where.missing(:navigation_items) }

  validates :slug, presence: true
  validates :emoji, emoji: true

  belongs_to :site

  after_initialize do
    self[:add_to_navigation] = in_navigation? if persisted?
  end

  after_save do
    if in_navigation?
      site.main_navigation.remove(self) unless add_to_navigation
    elsif add_to_navigation
      site.main_navigation.add(self)
    end
  end

  def homepage?
    slug == '/'
  end

  def in_navigation?
    navigation_items.size.positive?
  end
end
