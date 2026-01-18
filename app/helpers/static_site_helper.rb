module StaticSiteHelper
  def static_site_inline_css
    Rails.root.join("app/assets/stylesheets/static_site.css").read
  end

  def static_site_copyright(site)
    site.copyright.gsub("{{CurrentYear}}", Time.zone.now.year.to_s)
  end

  def static_site_header_image_url(image)
    return nil unless image&.file&.attached?

    "/images/#{image.public_id}/desktop_x1.webp"
  end

  def static_site_header_image_srcset(image)
    return nil unless image&.file&.attached?

    Image::Variants::SIZES.map do |name, width|
      "/images/#{image.public_id}/#{name}.webp #{width}w"
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

    "/images/#{image.public_id}/#{variant}.webp"
  end

  def static_site_content_html(content_html)
    # rubocop:disable Rails/OutputSafety
    content_html.gsub(%r{/images/}, "/images/").html_safe
    # rubocop:enable Rails/OutputSafety
  end
end
