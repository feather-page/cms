module StaticSite
  module OutputPaths
    def post_output_path(post)
      if post.slug.present?
        "#{post.slug.sub(%r{^/}, '')}/index.html"
      else
        "posts/#{post.public_id.downcase}/index.html"
      end
    end

    def page_output_path(page)
      "#{page.slug.sub(%r{^/}, '')}/index.html"
    end

    def image_output_path(image, variant_key)
      extension = variant_key.to_s.split("_").last
      variant_name = variant_key.to_s.sub(/_#{extension}$/, "")
      "images/#{image.public_id}/#{variant_name}.#{extension}"
    end
  end
end
