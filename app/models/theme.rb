# frozen_string_literal: true

class Theme < ApplicationRecord
  include PublicIdable

  has_many :sites, dependent: :restrict_with_error

  validates :name, presence: true
  validates :hugo_theme, presence: true, uniqueness: true
  validates :public_id, presence: true, uniqueness: true

  def theme_path
    Rails.root.join("vendor/themes/#{hugo_theme}")
  end

  def to_s
    name
  end
end
