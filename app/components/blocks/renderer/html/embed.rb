module Blocks
  module Renderer
    module Html
      class Embed < Base
        delegate :service, :source, :caption, to: :block

        def embed_url
          block.embed
        end

        def size_attrs
          attrs = []
          attrs << "width=\"#{block.width}\"" if block.width
          attrs << "height=\"#{block.height}\"" if block.height
          attrs.join(" ")
        end

        erb_template <<~ERB
          <figure><iframe src="<%= embed_url %>" <%= raw(size_attrs) %> frameborder="0" allowfullscreen></iframe><% if caption.present? %><figcaption><%= raw(scrub_html(caption)) %></figcaption><% end %></figure>
        ERB
      end
    end
  end
end
