require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Book do
  describe "#to_html" do
    let(:block) do
      instance_double(Blocks::Book, book_public_id: "abc-123")
    end

    it "renders a Hugo book shortcode with the book public id" do
      expect(described_class.new(block).to_html).to eq('{{< book id="abc-123" >}}')
    end

    context "with a different book public id" do
      let(:block) do
        instance_double(Blocks::Book, book_public_id: "xyz-789")
      end

      it "renders a Hugo book shortcode with the correct id" do
        expect(described_class.new(block).to_html).to eq('{{< book id="xyz-789" >}}')
      end
    end
  end
end
