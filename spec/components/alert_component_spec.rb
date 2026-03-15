# frozen_string_literal: true

describe AlertComponent, type: :component do
  it "renders an alert with content" do
    render_inline(described_class.new) { "Hello world" }
    expect(page).to have_css('div.alert[role="alert"]', text: "Hello world")
  end

  it "renders with the info variant by default" do
    render_inline(described_class.new) { "Info" }
    expect(page).to have_css("div.alert.alert--info")
  end

  it "renders a success variant" do
    render_inline(described_class.new(variant: :success)) { "Success" }
    expect(page).to have_css("div.alert.alert--success")
  end

  it "renders a danger variant" do
    render_inline(described_class.new(variant: :danger)) { "Error" }
    expect(page).to have_css("div.alert.alert--danger")
  end

  it "does not render a dismiss button by default" do
    render_inline(described_class.new) { "Hello" }
    expect(page).to have_no_css(".alert__dismiss")
  end

  it "renders a dismiss button when dismissible" do
    render_inline(described_class.new(dismissible: true)) { "Hello" }
    expect(page).to have_css("button.alert__dismiss")
  end
end
