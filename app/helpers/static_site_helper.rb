module StaticSiteHelper
  def static_site_inline_css
    Rails.root.join("app/assets/stylesheets/static_site.css").read
  end

  def static_site_copyright(site)
    site.copyright.gsub("{{CurrentYear}}", Time.zone.now.year.to_s)
  end

  def static_site_header_image_url(image)
    return nil unless image&.file&.attached?

    "#{static_site_base_url}images/#{image.public_id}/desktop_x1.webp"
  end

  def static_site_header_image_srcset(image)
    return nil unless image&.file&.attached?

    Image::Variants::SIZES.map do |name, width|
      "#{static_site_base_url}images/#{image.public_id}/#{name}.webp #{width}w"
    end.join(", ")
  end

  def static_site_rating_stars(rating)
    return nil if rating.blank?

    filled = "\u2605" * rating
    empty = "\u2606" * (5 - rating)
    filled + empty
  end

  def static_site_image_url(image, variant = :desktop_x1)
    return nil unless image&.file&.attached?

    "#{static_site_base_url}images/#{image.public_id}/#{variant}.webp"
  end

  def static_site_content_html(content_html)
    # rubocop:disable Rails/OutputSafety
    content_html.gsub(%r{/images/}, "#{static_site_base_url}images/").html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def static_site_post_url(post)
    path = if post.slug.present?
             "#{post.slug.sub(%r{^/}, '')}/"
           else
             "posts/#{post.public_id.downcase}/"
           end
    "#{static_site_base_url}#{path}"
  end

  def static_site_project_url(project)
    slug = project.slug.sub(%r{^/}, "")
    "#{static_site_base_url}projects/#{slug}/"
  end

  def pagination_page_numbers(current_page, total_pages)
    return (1..total_pages).to_a if total_pages <= 7

    visible = Set.new([1, total_pages, current_page])
    visible << current_page - 1 if current_page > 1
    visible << current_page + 1 if current_page < total_pages

    if current_page <= 3
      (1..4).each { |p| visible << p }
    elsif current_page >= total_pages - 2
      ((total_pages - 3)..total_pages).each { |p| visible << p }
    end

    pages = []
    visible.sort.each do |page|
      pages << :gap if pages.last.is_a?(Integer) && page > pages.last + 1
      pages << page
    end
    pages
  end

  private

  def static_site_base_url
    @base_url || "/" # rubocop:disable Rails/HelperInstanceVariable
  end
end
