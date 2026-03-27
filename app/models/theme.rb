class Theme < ApplicationRecord
  has_many :sites, dependent: :restrict_with_error

  validates :name, presence: true
  validates :hugo_theme, presence: true, uniqueness: true
end
