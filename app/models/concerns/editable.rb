module Editable
  extend ActiveSupport::Concern

  included do
    has_many :images, as: :imageable, dependent: :destroy
    after_save :assign_images

    before_save :parse_content
  end

  def content
    content = read_attribute(:content)
    content.presence || []
  end

  def blocks
    parse_content
    Blocks.from_content(content)
  end

  def static_site_html
    Blocks::Renderer::StaticSiteHtml.render(blocks)
  end

  def hugo_html
    Blocks::Renderer::HugoHtml.render(blocks)
  end

  def content_html
    Blocks::Renderer::Html.render(blocks)
  end

  private

  def parse_content
    self.content = Blocks.from_editor_js(JSON.parse(content)) if content.is_a?(String)
  end

  def assign_images
    blocks.select { |block| block.type == 'image' }.each do |block|
      block.image.update(imageable: self)
    end
  end
end
