# frozen_string_literal: true

class IconComponent < ViewComponent::Base
  # Maps old Bootstrap Icons names to Lucide icon keys.
  # Lucide names are also accepted directly.
  NAME_MAP = {
    # Bootstrap → Lucide mappings
    "pen" => "pencil",
    "book" => "book-open",
    "box-seam-fill" => "package",
    "briefcase" => "briefcase",
    "caret-down-square" => "chevron-down",
    "caret-up-square" => "chevron-up",
    "envelope-check" => "mail-check",
    "eye" => "eye",
    "file-plus" => "file-plus",
    "files" => "files",
    "gear" => "settings",
    "globe" => "globe",
    "house" => "home",
    "house-add" => "house-plus",
    "houses" => "building-2",
    "pencil" => "pencil",
    "people-fill" => "users",
    "person-plus" => "user-plus",
    "rocket" => "rocket",
    "star" => "star",
    "trash" => "trash-2",
    "image" => "image",
    "upload" => "upload",
    "file-text" => "file-text",
    "box-seam" => "package",
    "mail" => "mail",
    "plus" => "plus",
    "minus" => "minus",
    "file" => "file"
  }.freeze

  # Lucide SVG path data (24x24 viewBox, stroke-based).
  # Each value is an array of path `d` attributes.
  LUCIDE_ICONS = {
    "pencil" => {
      paths: [
        "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
        "m15 5 4 4"
      ]
    },
    "book-open" => {
      paths: [
        "M12 7v14",
        "M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"
      ]
    },
    "package" => {
      paths: [
        "M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z",
        "M12 22V12",
        "M3.3 7 12 12l8.7-5",
        "M7.5 4.27l9 5.15"
      ]
    },
    "briefcase" => {
      paths: [
        "M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16",
        "M2 10a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2z" # rect as path
      ]
    },
    "chevron-down" => {
      paths: [
        "m6 9 6 6 6-6"
      ]
    },
    "chevron-up" => {
      paths: [
        "m18 15-6-6-6 6"
      ]
    },
    "mail-check" => {
      paths: [
        "M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8",
        "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7",
        "m16 19 2 2 4-4"
      ]
    },
    "eye" => {
      paths: [
        "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0",
        "M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z" # circle as path
      ]
    },
    "file-plus" => {
      paths: [
        "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z",
        "M14 2v4a2 2 0 0 0 2 2h4",
        "M12 18v-6",
        "M9 15h6"
      ]
    },
    "files" => {
      paths: [
        "M20 7h-3a2 2 0 0 1-2-2V2",
        "M9 18a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h7l4 4v10a2 2 0 0 1-2 2z",
        "M3 7.6v12.8A1.6 1.6 0 0 0 4.6 22h9.8"
      ]
    },
    "settings" => {
      paths: [
        "M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z",
        "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z" # circle as path
      ]
    },
    "globe" => {
      paths: [
        "M21.54 15H17a2 2 0 0 0-2 2v4.54",
        "M7 3.34V5a3 3 0 0 0 3 3a2 2 0 0 1 2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2c0-1.1.9-2 2-2h3.17",
        "M11 21.95V18a2 2 0 0 0-2-2a2 2 0 0 1-2-2v-1a2 2 0 0 0-2-2H1.05",
        "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z" # circle as path
      ]
    },
    "home" => {
      paths: [
        "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",
        "M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
      ]
    },
    "house-plus" => {
      paths: [
        "M13.22 2.416a2 2 0 0 0-2.511.057l-7 5.999A2 2 0 0 0 3 10v9a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7.354",
        "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",
        "M15 6h6",
        "M18 3v6"
      ]
    },
    "building-2" => {
      paths: [
        "M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z",
        "M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2",
        "M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2",
        "M10 6h4",
        "M10 10h4",
        "M10 14h4",
        "M10 18h4"
      ]
    },
    "users" => {
      paths: [
        "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",
        "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z", # circle as path
        "M22 21v-2a4 4 0 0 0-3-3.87",
        "M16 3.13a4 4 0 0 1 0 7.75"
      ]
    },
    "user-plus" => {
      paths: [
        "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",
        "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z", # circle as path
        "M19 8v6",
        "M22 11h-6"
      ]
    },
    "rocket" => {
      paths: [
        "M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z",
        "M12 15l-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z",
        "M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0",
        "M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"
      ]
    },
    "star" => {
      paths: [
        "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"
      ]
    },
    "trash-2" => {
      paths: [
        "M3 6h18",
        "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6",
        "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",
        "M10 11v6",
        "M14 11v6"
      ]
    },
    "image" => {
      paths: [
        "M21 3H3a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z", # rect as path
        "M8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z", # circle as path
        "m21 15-5-5L5 21"
      ]
    },
    "upload" => {
      paths: [
        "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4",
        "M17 8l-5-5-5 5",
        "M12 3v12"
      ]
    },
    "circle-help" => {
      paths: [
        "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
        "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3",
        "M12 17h.01"
      ]
    },
    "file-text" => {
      paths: [
        "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z",
        "M14 2v4a2 2 0 0 0 2 2h4",
        "M10 9H8",
        "M16 13H8",
        "M16 17H8"
      ]
    },
    "mail" => {
      paths: [
        "M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z",
        "M22 7l-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"
      ]
    },
    "plus" => {
      paths: [
        "M5 12h14",
        "M12 5v14"
      ]
    },
    "minus" => {
      paths: [
        "M5 12h14"
      ]
    },
    "file" => {
      paths: [
        "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z",
        "M14 2v4a2 2 0 0 0 2 2h4"
      ]
    }
  }.freeze

  # Social media / brand icons are loaded from vendor/icons/ SVG files.
  SOCIAL_MEDIA_ICONS = %w[
    facebook github gitlab instagram linkedin
    mastodon reddit rss vimeo whatsapp youtube
  ].freeze

  def initialize(name:, size: 20, css_class: nil)
    @name = name.to_s
    @size = size
    @css_class = css_class
  end

  def call
    # Resolve the name through the mapping
    resolved = NAME_MAP[@name] || @name

    # Try Lucide icon first
    if LUCIDE_ICONS.key?(resolved)
      render_lucide_svg(resolved)
    elsif SOCIAL_MEDIA_ICONS.include?(@name)
      render_social_media_svg(@name)
    else
      render_lucide_svg("circle-help") # fallback
    end
  end

  private

  def render_lucide_svg(icon_name)
    icon_data = LUCIDE_ICONS[icon_name] || LUCIDE_ICONS["circle-help"]
    paths = icon_data[:paths]

    path_tags = paths.map { |d| tag.path(d: d) }.join.html_safe

    content_tag(:svg,
      path_tags,
      xmlns: "http://www.w3.org/2000/svg",
      width: @size,
      height: @size,
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": "2",
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      class: css_classes,
      "aria-hidden": "true")
  end

  def render_social_media_svg(icon_name)
    svg_path = Rails.root.join("vendor", "icons", "#{icon_name}.svg")
    return render_lucide_svg("globe") unless svg_path.exist?

    raw_svg = svg_path.read
    escaped_size = CGI.escapeHTML(@size.to_s)
    escaped_classes = CGI.escapeHTML(css_classes)
    # Update width/height to match our size and add our CSS classes
    raw_svg = raw_svg
      .gsub(/width="[^"]*"/, %(width="#{escaped_size}"))
      .gsub(/height="[^"]*"/, %(height="#{escaped_size}"))
      .gsub(/class="[^"]*"/, %(class="#{escaped_classes}"))
    # Add aria-hidden to the SVG element
    raw_svg = raw_svg.sub(/<svg\b/, '<svg aria-hidden="true"')

    raw_svg.html_safe
  end

  def css_classes
    classes = ["icon"]
    classes << @css_class if @css_class.present?
    classes.join(" ")
  end
end
