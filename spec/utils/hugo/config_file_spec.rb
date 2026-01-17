describe Hugo::ConfigFile do
  subject(:config_file) { described_class.new(site, deployment_target) }

  let(:deployment_target) { create(:deployment_target) }
  let(:site) { deployment_target.site }

  describe '#relative_path' do
    it 'returns the relative path to the config file' do
      expect(config_file.relative_path).to eq('config.json')
    end
  end

  describe '#content' do
    let(:content) { JSON.parse(config_file.content) }
    let!(:social_media_links) { create_list(:social_media_link, 3, site: site) }

    it 'contains social media links' do
      social_media_links.map do |l|
        expect(config_file.social).to include({ name: l.name, url: l.url, icon: l.icon, svg: l.svg })
      end
    end

    it 'contains navigation links' do
      page = create(:page, title: 'Foobar', slug: 'foobar', emoji: '🦄', site:)
      site.main_navigation.add(page)
      expect(content['menu']['main']).to include(
        {
          "name" => page.title,
          "url" => page.slug,
          "weight" => 1,
          "params" => { "emoji" => page.emoji }
        }
      )
    end

    it 'contains the sites copyright with the current year' do
      site.update(copyright: 'Foobar {{CurrentYear}}')
      expect(content['copyright']).to eq("Foobar #{Time.zone.now.year}")
    end

    context "with internal provider" do
      let(:deployment_target) { create(:deployment_target, :staging) }

      it "uses preview path as baseUrl" do
        expect(content["baseUrl"]).to eq("/preview/#{deployment_target.id}/")
      end
    end

    context "with external provider" do
      let(:deployment_target) { create(:deployment_target, :fastmail) }

      it "uses public hostname as baseUrl" do
        expect(content["baseUrl"]).to eq("https://#{deployment_target.public_hostname}/")
      end
    end
  end
end
