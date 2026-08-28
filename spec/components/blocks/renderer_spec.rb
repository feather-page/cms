# frozen_string_literal: true

describe Blocks::Renderer do
  describe ".render" do
    subject(:html) { described_class.render(blocks, routes:) }

    let(:routes) { instance_double(StaticSite::Routes) }

    context "with paragraph blocks" do
      let(:blocks) do
        [
          Blocks::Paragraph.new(id: 'JXyF2m2GZQ', text: 'Foo'),
          Blocks::Paragraph.new(id: 'Ufe53LgSM4', text: 'Bar')
        ]
      end

      it "renders each block as HTML" do
        expect(html).to eq('<p>Foo</p><p>Bar</p>')
      end
    end

    context "with an image block" do
      let(:image) { create(:image) }
      let(:blocks) do
        [Blocks::Image.new(id: 'img1', image_id: image.public_id, caption: '')]
      end

      before do
        allow(image).to receive_messages(width: 10, height: 10)
        allow(Image).to receive(:find).with(image.public_id).and_return(image)
        allow(routes).to receive(:image_url).with(image, anything)
          .and_return("/images/#{image.public_id}/mobile_x1.webp")
      end

      it "passes routes to the block renderer" do
        expect(html).to include("/images/#{image.public_id}/mobile_x1.webp")
      end
    end
  end
end