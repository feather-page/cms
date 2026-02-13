module Taggable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_tags
  end

  def tag_list
    tags.to_s.split(",").map(&:strip).compact_blank
  end

  def tag_list=(list)
    self.tags = Array(list).join(", ")
  end

  def tagged?
    tag_list.any?
  end

  private

  def normalize_tags
    return if tags.blank?

    self.tags = tags.split(",").map { |t| t.strip.downcase }.compact_blank.uniq.join(", ")
    self.tags = nil if tags.blank?
  end
end
