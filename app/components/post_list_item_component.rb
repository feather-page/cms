# frozen_string_literal: true

class PostListItemComponent < ViewComponent::Base
  def initialize(post:, site:)
    @post = post
    @site = site
  end

  def short_post?
    @post.title.blank?
  end

  def display_text
    if short_post?
      @post.content_excerpt(length: 120)
    else
      @post.title
    end
  end

  def status_badge_class
    @post.draft? ? "list-row__badge--draft" : "list-row__badge--published"
  end

  def status_label
    @post.draft? ? "Draft" : "Published"
  end

  def icon_content
    if @post.thumbnail_image&.file&.attached?
      helpers.image_tag(@post.thumbnail_image.file.variant(:mobile_x1_webp), class: "list-row__thumbnail")
    elsif @post.emoji.present?
      content_tag(:span, @post.emoji, class: "list-row__emoji")
    elsif short_post?
      helpers.icon("chat-left-text")
    else
      helpers.icon("file-text")
    end
  end

  def edit_path
    helpers.edit_site_post_path(@site, @post)
  end

  def formatted_date
    @post.publish_at&.strftime("%-d. %b %Y")
  end
end
