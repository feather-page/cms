# frozen_string_literal: true

describe TableComponent, type: :component do
  it "renders a table with headers" do
    render_inline(described_class.new(headers: %w[Name Email])) do
      "<tr><td>Alice</td><td>alice@example.com</td></tr>".html_safe
    end
    expect(page).to have_css(".table-wrapper table.table")
    expect(page).to have_css("thead th", text: "Name")
    expect(page).to have_css("thead th", text: "Email")
  end

  it "renders body content" do
    render_inline(described_class.new(headers: %w[Name])) do
      "<tr><td>Alice</td></tr>".html_safe
    end
    expect(page).to have_css("tbody td", text: "Alice")
  end

  it "wraps the table for responsive scrolling" do
    render_inline(described_class.new(headers: %w[Col])) { "" }
    expect(page).to have_css(".table-wrapper")
  end
end
