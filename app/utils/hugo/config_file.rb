# frozen_string_literal: true

module Hugo
  class ConfigFile < BaseFile
    def relative_path
      "config.json"
    end

    def content
      config_hash.to_json
    end

    private

    def config_hash
      {
        baseUrl: base_url,
        languageCode: site.language_code,
        title: site.title,
        copyright: formatted_copyright,
        summaryLength: site.summary_length,
        params: { emoji: site.emoji, social: social_links },
        theme: site.theme.hugo_theme,
        menu: { main: main_navigation },
        markup: {
          goldmark: { renderer: { unsafe: true } },
          highlight: {
            guessSyntax: true,
            lineNos: true,
            lineNumbersInTable: true,
            style: "monokai",
            tabWidth: 2,
          },
        },
      }
    end

    def main_navigation
      site.main_navigation.navigation_items.ordered.map do |item|
        {
          name: item.title,
          url: item.slug,
          weight: item.position,
          params: { emoji: item.emoji },
        }
      end
    end

    def social_links
      site.social_media_links.map { |l| { name: l.name, url: l.url, icon: l.icon, svg: l.svg } }
    end

    def formatted_copyright
      site.copyright.gsub("{{CurrentYear}}", Time.zone.now.year.to_s)
    end

    def base_url
      return "/preview/#{deployment_target.public_id}/" if deployment_target.provider == "internal"

      "https://#{deployment_target.public_hostname}/"
    end
  end
end
