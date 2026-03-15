# frozen_string_literal: true

describe PageHeaderComponent, type: :component do
  it "renders a title" do
    render_inline(described_class.new(title: "All Posts"))
    expect(page).to have_css(".page-header__title", text: "All Posts")
  end

  it "renders action buttons in the actions area" do
    render_inline(described_class.new(title: "Posts")) do
      "<button>New Post</button>".html_safe
    end
    expect(page).to have_css(".page-header__actions button", text: "New Post")
  end

  it "does not render actions area when no content is given" do
    render_inline(described_class.new(title: "Posts"))
    expect(page).to have_no_css(".page-header__actions")
  end
end
