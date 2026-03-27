require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Embed do
  describe "#to_html" do
    context "with a YouTube embed using watch URL" do
      let(:block) do
        instance_double(
          Blocks::Embed,
          service: "youtube",
          source: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
          embed: "https://www.youtube.com/embed/dQw4w9WgXcQ",
          caption: ""
        )
      end

      it "renders a Hugo youtube shortcode" do
        expect(described_class.new(block).to_html).to eq("{{< youtube dQw4w9WgXcQ >}}")
      end
    end

    context "with a YouTube embed using short URL" do
      let(:block) do
        instance_double(
          Blocks::Embed,
          service: "youtube",
          source: "https://youtu.be/dQw4w9WgXcQ",
          embed: "https://www.youtube.com/embed/dQw4w9WgXcQ",
          caption: ""
        )
      end

      it "renders a Hugo youtube shortcode" do
        expect(described_class.new(block).to_html).to eq("{{< youtube dQw4w9WgXcQ >}}")
      end
    end

    context "with a YouTube embed using embed URL" do
      let(:block) do
        instance_double(
          Blocks::Embed,
          service: "youtube",
          source: "https://www.youtube.com/embed/dQw4w9WgXcQ",
          embed: "https://www.youtube.com/embed/dQw4w9WgXcQ",
          caption: ""
        )
      end

      it "renders a Hugo youtube shortcode" do
        expect(described_class.new(block).to_html).to eq("{{< youtube dQw4w9WgXcQ >}}")
      end
    end

    context "with a Vimeo embed" do
      let(:block) do
        instance_double(
          Blocks::Embed,
          service: "vimeo",
          source: "https://vimeo.com/123456789",
          embed: "https://player.vimeo.com/video/123456789",
          caption: ""
        )
      end

      it "renders a Hugo vimeo shortcode" do
        expect(described_class.new(block).to_html).to eq("{{< vimeo 123456789 >}}")
      end
    end

    context "with a generic embed without caption" do
      let(:block) do
        instance_double(
          Blocks::Embed,
          service: "other",
          source: "https://example.com",
          embed: "https://example.com/embed",
          caption: ""
        )
      end

      it "renders a Hugo embed shortcode with url" do
        expect(described_class.new(block).to_html).to eq('{{< embed url="https://example.com/embed" >}}')
      end
    end

    context "with a generic embed with caption" do
      let(:block) do
        instance_double(
          Blocks::Embed,
          service: "other",
          source: "https://example.com",
          embed: "https://example.com/embed",
          caption: "An embedded widget"
        )
      end

      it "renders a Hugo embed shortcode with url and caption" do
        expect(described_class.new(block).to_html).to eq('{{< embed url="https://example.com/embed" caption="An embedded widget" >}}')
      end
    end
  end
end
