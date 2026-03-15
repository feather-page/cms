# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostListItemComponent, type: :component do
  let(:site) { create(:site) }

  describe "titled post" do
    let(:post) { create(:post, site: site, title: "My Great Post", emoji: "🔔", draft: false, publish_at: Time.zone.local(2026, 2, 14)) }

    it "renders title" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_text("My Great Post")
    end

    it "renders emoji" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_text("🔔")
    end

    it "renders as a link to edit" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_css("a.list-row__link[href*='/posts/#{post.public_id}']")
    end

    it "renders formatted date" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_text("14. Feb 2026")
    end

    it "shows published badge" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_css(".list-row__badge--published", text: "Published")
    end
  end

  describe "short post (no title)" do
    let(:post) do
      create(:post, site: site, title: nil, draft: false, publish_at: Time.current,
             content: [{ "id" => "abc123", "type" => "paragraph", "text" => "This is a short post without a title, just content." }])
    end

    it "renders content excerpt instead of title" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_text("This is a short post")
    end

    it "marks title as short-post style" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_css(".list-row__title--short")
    end
  end

  describe "draft post" do
    let(:post) { create(:post, site: site, draft: true) }

    it "shows draft badge" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_css(".list-row__badge--draft", text: "Draft")
    end
  end

  describe "tagged post" do
    let(:post) { create(:post, :tagged, site: site, draft: false) }

    it "renders tag pills" do
      render_inline(described_class.new(post: post, site: site))
      expect(page).to have_css(".list-row__tag", minimum: 1)
    end
  end
end
