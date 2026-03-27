module Hugo
  class ThemeLinker
    def self.link(build_path:)
      themes_link = build_path.join("themes")
      FileUtils.rm_f(themes_link)
      FileUtils.ln_s(Rails.root.join("vendor/themes"), themes_link)
    end
  end
end
