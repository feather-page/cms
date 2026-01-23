module Blocks
  MAPPING = {
    'book' => Book,
    'code' => Code,
    'header' => Header,
    'image' => Image,
    'list' => List,
    'paragraph' => Paragraph,
    'quote' => Quote,
    'table' => Table
  }.freeze

  def self.from_content(content)
    content.filter_map do |block_hash|
      block_hash = block_hash.symbolize_keys
      klass = MAPPING[block_hash[:type]]
      next unless klass

      klass.new(**block_hash)
    end
  end

  def self.from_editor_js(content)
    content.fetch('blocks', []).filter_map do |block_hash|
      klass = MAPPING[block_hash['type']]
      next unless klass

      klass.from_editor_js(block_hash)
    end
  end

  def self.to_editor_js(blocks)
    data = {
      'time' => Time.now.to_i,
      'blocks' => blocks.map(&:to_editor_js)
    }

    JSON.dump(data)
  end
end
