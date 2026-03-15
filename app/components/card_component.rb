# frozen_string_literal: true

class CardComponent < ViewComponent::Base
  def initialize(hover: false, **html_options)
    @hover = hover
    @html_options = html_options
  end

  def call
    css = class_names("card", { "card--hover" => @hover }, @html_options[:class])
    content_tag(:div, content, **@html_options.except(:class).merge(class: css))
  end
end
