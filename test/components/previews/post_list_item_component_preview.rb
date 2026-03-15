# frozen_string_literal: true

class PostListItemComponentPreview < Lookbook::Preview
  # @label Mit Titel und Emoji
  def with_title_and_emoji
    site = Site.first
    post = site.posts.where.not(title: [nil, ""]).first
    render PostListItemComponent.new(post: post, site: site) if post
  end

  # @label Short Post (ohne Titel)
  def short_post
    site = Site.first
    post = site.posts.where(title: [nil, ""]).first
    if post
      render PostListItemComponent.new(post: post, site: site)
    else
      # Fallback: show first post
      post = site.posts.first
      render PostListItemComponent.new(post: post, site: site) if post
    end
  end

  # @label Draft
  def draft
    site = Site.first
    post = site.posts.where(draft: true).first
    if post
      render PostListItemComponent.new(post: post, site: site)
    else
      post = site.posts.first
      render PostListItemComponent.new(post: post, site: site) if post
    end
  end

  # @label Mit Tags
  def with_tags
    site = Site.first
    post = site.posts.where.not(tags: [nil, ""]).first
    if post
      render PostListItemComponent.new(post: post, site: site)
    else
      post = site.posts.first
      render PostListItemComponent.new(post: post, site: site) if post
    end
  end
end
