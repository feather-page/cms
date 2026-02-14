# frozen_string_literal: true

describe Hugo::PostFile do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site: site) }
  let(:post) { create(:post, site: site, title: "Test Post", publish_at: Date.new(2026, 1, 15)) }

  subject(:post_file) { described_class.new(post, deployment_target) }

  describe "#relative_path" do
    it "returns the content path based on public_id" do
      expect(post_file.relative_path).to eq("content/posts/#{post.public_id}.html")
    end
  end

  describe "#content" do
    it "includes front matter as JSON" do
      front_matter_line = post_file.content.lines.first
      data = JSON.parse(front_matter_line)

      expect(data["date"]).to eq("2026-01-15")
      expect(data["title"]).to eq("Test Post")
    end

    it "includes the slug when present" do
      post.update!(slug: "/my-post")
      data = JSON.parse(post_file.content.lines.first)

      expect(data["url"]).to eq("/my-post")
    end

    it "marks short posts" do
      post.update!(title: nil)
      data = JSON.parse(post_file.content.lines.first)

      expect(data["short"]).to be true
    end

    it "includes emoji when present" do
      post.update!(emoji: "\u{1F4DA}")
      data = JSON.parse(post_file.content.lines.first)

      expect(data["emoji"]).to eq("\u{1F4DA}")
    end

    context "with a book" do
      let(:book) { create(:book, site: site, title: "Clean Code", author: "Robert Martin", rating: 4) }

      before { book.update!(post: post) }

      it "includes book data in front matter" do
        data = JSON.parse(post_file.content.lines.first)

        expect(data["book"]["title"]).to eq("Clean Code")
        expect(data["book"]["author"]).to eq("Robert Martin")
        expect(data["book"]["rating"]).to eq(4)
        expect(data["book"]["rating_stars"]).to eq("\u2605\u2605\u2605\u2605\u2606")
      end
    end

    context "with a header image" do
      let(:image) { create(:image, site: site) }

      before { post.update!(header_image: image) }

      it "includes header image data in front matter" do
        data = JSON.parse(post_file.content.lines.first)

        expect(data["header_image"]["url"]).to include(image.public_id)
        expect(data["header_image"]["srcset"]).to include(image.public_id)
      end
    end
  end
end
