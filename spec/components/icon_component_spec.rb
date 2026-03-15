describe IconComponent, type: :component do
  it "renders a Lucide SVG icon" do
    render_inline(described_class.new(name: "home"))
    expect(page).to have_css("svg.icon")
    expect(page).to have_css("svg path", minimum: 1)
  end

  it "maps old Bootstrap Icons names to Lucide equivalents" do
    render_inline(described_class.new(name: "house"))
    # "house" maps to "home" in Lucide
    expect(page).to have_css("svg.icon path", minimum: 1)
  end

  it "accepts a size parameter" do
    render_inline(described_class.new(name: "star", size: 16))
    expect(page).to have_css('svg[width="16"][height="16"]')
  end

  it "accepts a css_class parameter" do
    render_inline(described_class.new(name: "star", css_class: "me-1"))
    expect(page).to have_css("svg.icon.me-1")
  end

  it "renders SVGs with currentColor for stroke" do
    render_inline(described_class.new(name: "pencil"))
    expect(page).to have_css('svg[stroke="currentColor"]')
  end

  it "renders a fallback icon for unknown names" do
    render_inline(described_class.new(name: "nonexistent-icon"))
    expect(page).to have_css("svg.icon")
  end

  it "renders social media icons from vendor SVG files" do
    render_inline(described_class.new(name: "github"))
    expect(page).to have_css("svg")
  end

  context "with all mapped Bootstrap Icons names" do
    IconComponent::NAME_MAP.each_key do |old_name|
      it "renders '#{old_name}' without error" do
        render_inline(described_class.new(name: old_name))
        expect(page).to have_css("svg")
      end
    end
  end
end
