# frozen_string_literal: true

module Blocks
  module Renderer
    class Code < Base
      erb_template '<pre><code><%= block.code %></code></pre>'
    end
  end
end