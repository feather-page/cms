# frozen_string_literal: true

describe Hugo::ConfigFile do
  let(:theme) { create(:theme, :simple_emoji) }
  let(:site) { create(:site, title: "My Blog", language_code: "en", theme: theme) }
  let(:deployment_target) { create(:deployment_target, :staging, site: site) }

  subject(:config_file) { described_class.new(site, deployment_target) }

  describe "#relative_path" do
    it "returns config.json" do
      expect(config_file.relative_path).to eq("config.json")
    end
  end

  describe "#content" do
    let(:config) { JSON.parse(config_file.content) }

    it "includes the site title" do
      expect(config["title"]).to eq("My Blog")
    end

    it "includes the language code" do
      expect(config["languageCode"]).to eq("en")
    end

    it "includes the theme" do
      expect(config["theme"]).to eq("simple_emoji")
    end

    it "includes social media links" do
      create(:social_media_link, site: site, name: "GitHub", url: "https://github.com/test")

      expect(config["params"]["social"].first["name"]).to eq("GitHub")
    end

    it "includes navigation items" do
      page = create(:page, site: site, title: "About", slug: "/about")
      site.main_navigation.add(page)

      expect(config["menu"]["main"].first["name"]).to eq("About")
    end

    context "with internal deployment target" do
      it "uses preview base URL" do
        expect(config["baseUrl"]).to eq("/preview/#{deployment_target.public_id}/")
      end
    end

    context "with production deployment target" do
      let(:deployment_target) { create(:deployment_target, :fastmail, site: site) }

      it "uses public hostname as base URL" do
        expect(config["baseUrl"]).to eq("https://#{deployment_target.public_hostname}/")
      end
    end

    it "includes goldmark unsafe renderer setting" do
      expect(config.dig("markup", "goldmark", "renderer", "unsafe")).to be true
    end

    it "substitutes year in copyright" do
      site.update!(copyright: "\u00a9 {{CurrentYear}}")

      expect(config["copyright"]).to eq("\u00a9 #{Time.zone.now.year}")
    end
  end
end
