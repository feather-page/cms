describe Sites::UpdateSite do
  subject(:outcome) do
    described_class.execute(
      emoji:,
      title:,
      language_code:,
      domain:,
      current_user:,
      copyright:,
      site:
    )
  end

  let(:site) { create(:site) }
  let(:current_user) { build(:user) }

  describe "#execute" do
    let(:title) { "New title" }
    let(:language_code) { "fr" }
    let(:domain) { "example.example.com" }
    let(:emoji) { "\u{1F389}" }
    let(:copyright) { "\u00a9 2021" }

    it "updates the site" do
      expect(outcome).to be_success
      expect(outcome.site.title).to eql(title)
      expect(outcome.site.copyright).to eql(copyright)
      expect(outcome.site.language_code).to eql(language_code)
      expect(outcome.site.domain).to eql("example.example.com")
    end
  end
end
