# frozen_string_literal: true

class ModalComponent < ViewComponent::Base
  def initialize(id:, title: nil)
    @id = id
    @title = title
  end

  def title?
    @title.present?
  end
end
