require "cgi"

module JekyllImporter
  module HtmlCleaner
    NAMED_ENTITIES = {
      "&rsquo;" => "\u2019", "&lsquo;" => "\u2018",
      "&rdquo;" => "\u201D", "&ldquo;" => "\u201C",
      "&mdash;" => "\u2014", "&ndash;" => "\u2013",
      "&hellip;" => "\u2026", "&nbsp;" => " ",
      "&laquo;" => "\u00AB", "&raquo;" => "\u00BB",
      "&bull;" => "\u2022", "&middot;" => "\u00B7",
      "&copy;" => "\u00A9", "&reg;" => "\u00AE",
      "&trade;" => "\u2122", "&deg;" => "\u00B0",
      "&euro;" => "\u20AC", "&pound;" => "\u00A3",
      "&yen;" => "\u00A5", "&cent;" => "\u00A2",
      "&times;" => "\u00D7", "&divide;" => "\u00F7",
      "&para;" => "\u00B6", "&sect;" => "\u00A7",
      "&dagger;" => "\u2020", "&Dagger;" => "\u2021",
      "&#038;" => "&"
    }.freeze

    private

    def clean_html(text)
      result = convert_markdown_links(text)
      result = convert_markdown_formatting(result)
      result = result.gsub(%r{<(?!/?(?:b|i|u|a|code)\b)[^>]+>}, "").gsub(/\s+/, " ").strip
      decode_entities(result)
    end

    def convert_markdown_links(text)
      result = text.gsub(%r{<(https?://[^>]+)>}) do
        url = Regexp.last_match(1)
        %(<a href="#{url}">#{url}</a>)
      end
      result.gsub(/(?<!!)\[([^\]]+)\]\(([^)]+)\)/) do
        link_text = Regexp.last_match(1)
        url = Regexp.last_match(2)
        %(<a href="#{url}">#{link_text}</a>)
      end
    end

    def convert_markdown_formatting(text)
      result = text.gsub(/`([^`]+)`/, '<code>\1</code>')
      result = result.gsub(/\*\*(.+?)\*\*/, '<b>\1</b>')
      result = result.gsub(/__(.+?)__/, '<b>\1</b>')
      result = result.gsub(/(?<![*\w])\*([^*]+?)\*(?![*\w])/, '<i>\1</i>')
      result.gsub(/(?<![_\w])_([^_]+?)_(?![_\w])/, '<i>\1</i>')
    end

    def decode_entities(text)
      result = NAMED_ENTITIES.reduce(text) { |s, (from, to)| s.gsub(from, to) }
      CGI.unescapeHTML(result)
    end
  end
end
