class Image < ApplicationRecord
  belongs_to :site
  belongs_to :imageable, polymorphic: true, optional: true

  scope :assigned, -> { where.not(imageable: nil) }
  scope :orphaned, -> { where(imageable: nil).where(created_at: ...2.days.ago) }

  has_one_attached :file do |attachable|
    Variants.configure(attachable)
  end

  validates :file, presence: true
  validate :acceptable_image

  def height
    file.metadata['height']
  end

  def width
    file.metadata['width']
  end

  def unsplash?
    unsplash_data.present?
  end

  def unsplash_photographer_name
    unsplash_data&.dig('photographer_name')
  end

  def unsplash_photographer_url
    unsplash_data&.dig('photographer_url')
  end

  def fs_path(variant: nil)
    return unless file.attached?

    key = variant ? file.variant(variant).processed.key : file.key

    ActiveStorage::Blob.service.path_for(key)
  end

  def acceptable_image
    return unless file.attached?

    errors.add(:file, 'is too big') if file.byte_size > 25.megabytes

    return if file.image?

    errors.add(:file, 'must be an image')
  end
end
