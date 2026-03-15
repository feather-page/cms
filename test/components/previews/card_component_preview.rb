# frozen_string_literal: true

class CardComponentPreview < Lookbook::Preview
  # @label Default
  def default
    render CardComponent.new do
      "This is a card with some content inside."
    end
  end

  # @label With Hover
  def with_hover
    render CardComponent.new(hover: true) do
      "Hover over this card to see the effect."
    end
  end
end
