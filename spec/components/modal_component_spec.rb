# frozen_string_literal: true

describe ModalComponent, type: :component do
  it "renders a dialog element with the given id" do
    render_inline(described_class.new(id: "my-modal")) { "Body" }
    expect(page).to have_css('dialog#my-modal.modal')
  end

  it "renders the title in the header" do
    render_inline(described_class.new(id: "m", title: "Confirm")) { "Body" }
    expect(page).to have_css(".modal__header .modal__title", text: "Confirm")
  end

  it "renders a close button when title is present" do
    render_inline(described_class.new(id: "m", title: "Confirm")) { "Body" }
    expect(page).to have_css("button.modal__close")
  end

  it "does not render header when no title" do
    render_inline(described_class.new(id: "m")) { "Body" }
    expect(page).to have_no_css(".modal__header")
  end

  it "renders body content" do
    render_inline(described_class.new(id: "m")) { "Hello modal" }
    expect(page).to have_css(".modal__body", text: "Hello modal")
  end
end
