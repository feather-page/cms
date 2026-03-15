# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  VARIANTS = %i[primary secondary danger ghost].freeze
  SIZES = %i[sm md].freeze

  def initialize(label:, variant: :primary, size: :md, icon: nil, href: nil, type: "button", **html_options)
    @label = label
    @variant = VARIANTS.include?(variant) ? variant : :primary
    @size = SIZES.include?(size) ? size : :md
    @icon = icon
    @href = href
    @type = type
    @html_options = html_options
  end

  def call
    css = class_names("btn", "btn--#{@variant}", "btn--#{@size}", @html_options.delete(:class))
    opts = @html_options.merge(class: css)

    inner = safe_join([icon_tag, @label].compact)

    if @href
      content_tag(:a, inner, opts.merge(href: @href))
    else
      content_tag(:button, inner, opts.merge(type: @type))
    end
  end

  private

  def icon_tag
    return nil unless @icon

    helpers.icon(@icon)
  end
end
