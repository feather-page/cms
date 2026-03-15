# frozen_string_literal: true

class TableComponentPreview < Lookbook::Preview
  # @label Default
  def default
    render TableComponent.new(headers: %w[Name Email Role]) do
      rows = [
        { name: "Alice", email: "alice@example.com", role: "Admin" },
        { name: "Bob", email: "bob@example.com", role: "Editor" }
      ]
      safe_join(rows.map { |row|
        content_tag(:tr,
          safe_join([
            content_tag(:td, row[:name]),
            content_tag(:td, row[:email]),
            content_tag(:td, row[:role])
          ])
        )
      })
    end
  end
end
