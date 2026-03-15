# frozen_string_literal: true

describe ButtonComponent, type: :component do
  it "renders a button with the given label" do
    render_inline(described_class.new(label: "Save"))
    expect(page).to have_button("Save")
  end

  it "renders with the primary variant by default" do
    render_inline(described_class.new(label: "Save"))
    expect(page).to have_css("button.btn.btn--primary")
  end

  it "renders a secondary variant" do
    render_inline(described_class.new(label: "Cancel", variant: :secondary))
    expect(page).to have_css("button.btn.btn--secondary")
  end

  it "renders a danger variant" do
    render_inline(described_class.new(label: "Delete", variant: :danger))
    expect(page).to have_css("button.btn.btn--danger")
  end

  it "renders a ghost variant" do
    render_inline(described_class.new(label: "More", variant: :ghost))
    expect(page).to have_css("button.btn.btn--ghost")
  end

  it "renders with md size by default" do
    render_inline(described_class.new(label: "Save"))
    expect(page).to have_css("button.btn--md")
  end

  it "renders with sm size" do
    render_inline(described_class.new(label: "Save", size: :sm))
    expect(page).to have_css("button.btn--sm")
  end

  it "renders as an anchor tag when href is provided" do
    render_inline(described_class.new(label: "Visit", href: "/home"))
    expect(page).to have_css('a.btn[href="/home"]', text: "Visit")
    expect(page).to have_no_css("button")
  end

  it "renders with an icon when provided" do
    render_inline(described_class.new(label: "Add", icon: "file-plus"))
    expect(page).to have_css("button svg.icon")
    expect(page).to have_text("Add")
  end

  it "sets the button type attribute" do
    render_inline(described_class.new(label: "Submit", type: "submit"))
    expect(page).to have_css('button[type="submit"]')
  end

  it "passes through additional html_options" do
    render_inline(described_class.new(label: "Save", data: { turbo: true }))
    expect(page).to have_css('button[data-turbo="true"]')
  end
end
