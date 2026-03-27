module Hugo
  class PageFile < BaseFile
    attr_reader :page

    def initialize(build_path:, page:)
      super(build_path: build_path)
      @page = page
    end

    def relative_path = "content/pages/#{page.slug}.html"

    def content
      "#{JSON.pretty_generate(front_matter)}\n\n#{page.hugo_html}"
    end

    private

    def front_matter
      meta = { title: page.title, url: "/#{page.slug}/", emoji: page.emoji }
      meta[:layout] = "home" if page.homepage?
      meta[:page_type] = page.page_type unless page.page_type == "default"
      if page.in_navigation?
        item = page.navigation_items.first
        meta[:menu] = { main: { weight: (item.position + 1) * 10 } }
      end
      if page.header_image.present?
        meta[:header_image] = {
          url: Hugo::ImageVariant.new(image: page.header_image, variant_name: :desktop_x1_webp).public_path
        }
      end
      meta
    end
  end
end
