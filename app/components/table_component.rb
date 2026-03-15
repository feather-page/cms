# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  def initialize(headers:)
    @headers = headers
  end
end
