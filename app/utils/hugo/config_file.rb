module Hugo
  class ConfigFile < BaseFile
    attr_reader :site, :deployment_target

    def initialize(build_path:, site:, deployment_target:)
      super(build_path: build_path)
      @site = site
      @deployment_target = deployment_target
    end

    def relative_path = "config.json"

    def content
      JSON.pretty_generate(config)
    end

    private

    def config
      {
        baseURL: "https://#{deployment_target.public_hostname}/",
        title: site.title,
        languageCode: site.language_code,
        theme: site.theme.hugo_theme,
        copyright: site.copyright,
        enableRobotsTXT: true,
        robotsNoIndex: deployment_target.type == "staging",
        minify: true,
        taxonomies: { tag: "tags" },
        pagination: { pagerSize: 25 },
        related: {
          threshold: 50, includeNewer: true,
          indices: [
            { name: "tags", weight: 100 },
            { name: "date", weight: 10 }
          ]
        },
        outputs: { home: %w[HTML RSS], section: %w[HTML RSS] },
        markup: { highlight: { style: "monokai", lineNos: false, noClasses: true } },
        params: { emoji: site.emoji }
      }
    end
  end
end
