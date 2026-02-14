# frozen_string_literal: true

describe Theme do
  describe "validations" do
    it "is valid with valid attributes" do
      theme = build(:theme)

      expect(theme).to be_valid
    end

    it "requires a name" do
      theme = build(:theme, name: nil)

      expect(theme).not_to be_valid
    end

    it "requires a hugo_theme" do
      theme = build(:theme, hugo_theme: nil)

      expect(theme).not_to be_valid
    end

    it "requires a unique hugo_theme" do
      create(:theme, hugo_theme: "my_theme")
      theme = build(:theme, hugo_theme: "my_theme")

      expect(theme).not_to be_valid
    end
  end

  describe "#theme_path" do
    it "returns the vendor theme path" do
      theme = build(:theme, hugo_theme: "simple_emoji")

      expect(theme.theme_path).to eq(Rails.root.join("vendor/themes/simple_emoji"))
    end
  end

  describe "#to_s" do
    it "returns the theme name" do
      theme = build(:theme, name: "Simple Emoji")

      expect(theme.to_s).to eq("Simple Emoji")
    end
  end

  describe "associations" do
    it "has many sites" do
      theme = create(:theme)
      create(:site, theme: theme)

      expect(theme.sites.count).to eq(1)
    end

    it "restricts deletion when sites exist" do
      theme = create(:theme)
      create(:site, theme: theme)

      expect { theme.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
