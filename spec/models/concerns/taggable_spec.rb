require "rails_helper"

RSpec.describe Taggable do
  subject(:post) { build(:post) }

  describe "#normalize_tags" do
    it "strips whitespace and downcases" do
      post.tags = "  Ruby , Rails , WEB  "
      post.validate
      expect(post.tags).to eq("ruby, rails, web")
    end

    it "deduplicates tags" do
      post.tags = "ruby, Rails, RUBY"
      post.validate
      expect(post.tags).to eq("ruby, rails")
    end

    it "sets nil for blank tags" do
      post.tags = "  ,  , "
      post.validate
      expect(post.tags).to be_nil
    end

    it "leaves nil tags as nil" do
      post.tags = nil
      post.validate
      expect(post.tags).to be_nil
    end
  end

  describe "#tag_list" do
    it "returns an array of tags" do
      post.tags = "ruby, rails, web"
      expect(post.tag_list).to eq(%w[ruby rails web])
    end

    it "returns empty array for nil tags" do
      post.tags = nil
      expect(post.tag_list).to eq([])
    end

    it "returns empty array for blank tags" do
      post.tags = ""
      expect(post.tag_list).to eq([])
    end
  end

  describe "#tag_list=" do
    it "sets tags from an array" do
      post.tag_list = %w[ruby rails]
      expect(post.tags).to eq("ruby, rails")
    end

    it "handles empty array" do
      post.tag_list = []
      expect(post.tags).to eq("")
    end
  end

  describe "#tagged?" do
    it "returns true when tags are present" do
      post.tags = "ruby"
      expect(post).to be_tagged
    end

    it "returns false when tags are nil" do
      post.tags = nil
      expect(post).not_to be_tagged
    end

    it "returns false when tags are blank" do
      post.tags = ""
      expect(post).not_to be_tagged
    end
  end
end
