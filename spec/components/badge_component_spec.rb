# frozen_string_literal: true

describe BadgeComponent, type: :component do
  it "renders a badge with the given label" do
    render_inline(described_class.new(label: "Draft"))
    expect(page).to have_css("span.badge", text: "Draft")
  end

  it "renders with the neutral variant by default" do
    render_inline(described_class.new(label: "Draft"))
    expect(page).to have_css("span.badge.badge--neutral")
  end

  it "renders an accent variant" do
    render_inline(described_class.new(label: "Featured", variant: :accent))
    expect(page).to have_css("span.badge.badge--accent")
  end

  it "renders a success variant" do
    render_inline(described_class.new(label: "Published", variant: :success))
    expect(page).to have_css("span.badge.badge--success")
  end

  it "renders a danger variant" do
    render_inline(described_class.new(label: "Error", variant: :danger))
    expect(page).to have_css("span.badge.badge--danger")
  end
end
