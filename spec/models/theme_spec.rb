require "rails_helper"

RSpec.describe Theme, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      theme = build(:theme)
      expect(theme).to be_valid
    end

    it "requires a name" do
      theme = build(:theme, name: nil)
      expect(theme).not_to be_valid
      expect(theme.errors[:name]).to include("can't be blank")
    end

    it "requires a hugo_theme" do
      theme = build(:theme, hugo_theme: nil)
      expect(theme).not_to be_valid
      expect(theme.errors[:hugo_theme]).to include("can't be blank")
    end

    it "requires a unique hugo_theme" do
      create(:theme, hugo_theme: "unique_theme")
      theme = build(:theme, hugo_theme: "unique_theme")
      expect(theme).not_to be_valid
      expect(theme.errors[:hugo_theme]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "has many sites" do
      theme = create(:theme)
      site = create(:site, theme: theme)
      expect(theme.sites).to include(site)
    end

    it "prevents deletion when sites exist" do
      theme = create(:theme)
      create(:site, theme: theme)
      expect(theme.destroy).to be_falsey
      expect(theme.errors[:base]).to include("Cannot delete record because dependent sites exist")
    end
  end
end
