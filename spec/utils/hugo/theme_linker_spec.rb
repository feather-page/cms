describe Hugo::ThemeLinker do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(build_path) }

  describe ".link" do
    it "creates a symlink to vendor/themes" do
      described_class.link(build_path:)

      themes_link = build_path.join("themes")
      expect(themes_link).to be_symlink
      expect(File.readlink(themes_link.to_s)).to eq(Rails.root.join("vendor/themes").to_s)
    end

    it "replaces an existing symlink" do
      old_target = Dir.mktmpdir
      FileUtils.ln_s(old_target, build_path.join("themes"))

      described_class.link(build_path:)

      themes_link = build_path.join("themes")
      expect(File.readlink(themes_link.to_s)).to eq(Rails.root.join("vendor/themes").to_s)
    ensure
      FileUtils.rm_rf(old_target)
    end
  end
end
