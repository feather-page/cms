module Hugo
  class PostFile < BaseFile
    attr_reader :post

    def initialize(build_path:, post:)
      super(build_path: build_path)
      @post = post
    end

    def relative_path = "content/posts/#{post.slug}.html"

    def content
      "#{JSON.pretty_generate(front_matter)}\n\n#{post.hugo_html}"
    end

    private

    def front_matter
      meta = {
        title: post.title,
        date: post.created_at.iso8601,
        url: "/#{post.slug}/",
        draft: post.draft?,
        emoji: post.emoji,
        tags: post.tag_list
      }
      meta[:publishDate] = post.publish_at.iso8601 if post.publish_at.present?
      meta[:summary] = post.content_excerpt if post.content_excerpt.present?
      if post.header_image.present?
        meta[:header_image] = header_image_data(post.header_image)
      end
      if post.respond_to?(:book) && post.book.present?
        meta[:book] = {
          public_id: post.book.public_id,
          title: post.book.title,
          author: post.book.author,
          emoji: post.book.emoji,
          rating: post.book.rating
        }
      end
      meta
    end

    def header_image_data(image)
      {
        url: Hugo::ImageVariant.new(image: image, variant_name: :desktop_x1_webp).public_path,
        srcset: Image::Variants::SIZES.map { |name, width|
          variant = Hugo::ImageVariant.new(image: image, variant_name: :"#{name}_webp")
          "#{variant.public_path} #{width}w"
        }.join(", ")
      }
    end
  end
end
