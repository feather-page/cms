describe Sites::CreateSite do
  subject(:outcome) do
    described_class.call(title:, current_user:, domain: "example.com", language_code: "en")
  end

  let(:title) { "My Site" }
  let(:current_user) { create(:user) }

  describe "#execute" do
    context "when site is valid" do
      let(:created_site) { outcome.site }

      it "creates a site" do
        expect(created_site).to be_persisted
      end

      it "adds the site to the current user" do
        expect(created_site.users).to include(current_user)
      end

      it "adds a home page to the site" do
        expect(created_site.pages.pluck(:title, :slug)).to eql([["Home", "/"]])
      end

      it "adds a staging deployment target to the site" do
        expect(
          created_site.deployment_targets.pluck(:public_hostname, :type, :provider)
        ).to include(
          [
            "#{created_site.public_id.downcase}.stage.#{ENV.fetch('BASE_HOSTNAME_AND_PORT')}",
            "staging", "internal"
          ]
        )
      end
    end

    context "when site is not valid" do
      let(:title) { nil }

      it "does not create a site" do
        expect { outcome }.not_to change(Site, :count)
        expect(outcome).not_to be_success
      end
    end
  end
end
