class Project < ApplicationRecord
  include PublicIdable
  include Editable
  include Taggable

  belongs_to :site

  enum :status, {
    ongoing: 0,
    completed: 1,
    paused: 2,
    abandoned: 3
  }

  enum :project_type, {
    professional: 0,
    personal: 1,
    open_source: 2,
    freelance: 3
  }, prefix: true

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :site_id }
  validates :short_description, presence: true
  validates :started_at, presence: true
  validates :status, presence: true
  validates :project_type, presence: true

  scope :ordered, -> { order(started_at: :desc) }

  def display_period
    return period if period.present?

    start_str = started_at.strftime("%m.%Y")
    end_str = ended_at&.strftime("%m.%Y") || "ongoing"
    "#{start_str} - #{end_str}"
  end

  def status_badge_class
    case status
    when "completed" then "success"
    when "ongoing" then "primary"
    when "paused" then "warning"
    else "secondary"
    end
  end

  def status_badge_variant
    case status
    when "completed" then :success
    when "ongoing" then :accent
    when "paused" then :neutral
    else :neutral
    end
  end
end
