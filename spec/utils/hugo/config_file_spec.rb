require "rails_helper"

RSpec.describe Hugo::ConfigFile do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, site: site, type: :production) }

  subject(:file) { described_class.new(build_path: build_path, site: site, deployment_target: deployment_target) }

  after { FileUtils.rm_rf(build_path) }

  describe "#relative_path" do
    it "returns config.json" do
      expect(file.relative_path).to eq("config.json")
    end
  end

  describe "#content" do
    let(:parsed) { JSON.parse(file.content) }

    it "returns valid JSON" do
      expect { parsed }.not_to raise_error
    end

    it "sets baseURL from deployment target hostname" do
      expect(parsed["baseURL"]).to eq("https://#{deployment_target.public_hostname}/")
    end

    it "sets the site title" do
      expect(parsed["title"]).to eq(site.title)
    end

    it "sets the language code" do
      expect(parsed["languageCode"]).to eq(site.language_code)
    end

    it "sets the theme from the site's theme" do
      expect(parsed["theme"]).to eq(site.theme.hugo_theme)
    end

    it "sets the copyright" do
      expect(parsed["copyright"]).to eq(site.copyright)
    end

    it "enables robots.txt" do
      expect(parsed["enableRobotsTXT"]).to be true
    end

    it "sets minify to true" do
      expect(parsed["minify"]).to be true
    end

    it "configures taxonomies" do
      expect(parsed["taxonomies"]).to eq("tag" => "tags")
    end

    it "configures pagination" do
      expect(parsed["pagination"]["pagerSize"]).to eq(25)
    end

    it "configures related content" do
      expect(parsed["related"]["threshold"]).to eq(50)
      expect(parsed["related"]["includeNewer"]).to be true
      expect(parsed["related"]["indices"].length).to eq(2)
    end

    it "configures output formats" do
      expect(parsed["outputs"]["home"]).to eq(%w[HTML RSS])
      expect(parsed["outputs"]["section"]).to eq(%w[HTML RSS])
    end

    it "configures markup highlighting" do
      expect(parsed["markup"]["highlight"]["style"]).to eq("monokai")
    end

    it "sets site emoji in params" do
      expect(parsed["params"]["emoji"]).to eq(site.emoji)
    end

    context "when deployment target is staging" do
      let(:deployment_target) { create(:deployment_target, site: site, type: :staging) }

      it "sets robotsNoIndex to true in params" do
        expect(parsed["params"]["robotsNoIndex"]).to be true
      end
    end

    context "when deployment target is production" do
      it "sets robotsNoIndex to false in params" do
        expect(parsed["params"]["robotsNoIndex"]).to be false
      end
    end
  end

  describe "#write" do
    it "writes config.json to the build path" do
      file.write
      written_path = build_path.join("config.json")
      expect(written_path).to exist
      parsed = JSON.parse(File.read(written_path))
      expect(parsed["title"]).to eq(site.title)
    end
  end
end
