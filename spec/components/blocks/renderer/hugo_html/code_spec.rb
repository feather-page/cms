require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Code do
  subject(:renderer) { described_class.new(block) }

  let(:block) { instance_double(Blocks::Code, language: "ruby", code: "puts 'hello'") }

  describe "#to_html" do
    it "renders a Hugo highlight shortcode" do
      expect(renderer.to_html).to eq("{{< highlight ruby >}}\nputs 'hello'\n{{< /highlight >}}")
    end

    context "with plaintext language" do
      let(:block) { instance_double(Blocks::Code, language: "plaintext", code: "some text") }

      it "renders with plaintext language" do
        expect(renderer.to_html).to eq("{{< highlight plaintext >}}\nsome text\n{{< /highlight >}}")
      end
    end

    context "with multiline code" do
      let(:block) { instance_double(Blocks::Code, language: "javascript", code: "const x = 1;\nconst y = 2;") }

      it "preserves line breaks in code" do
        expect(renderer.to_html).to eq("{{< highlight javascript >}}\nconst x = 1;\nconst y = 2;\n{{< /highlight >}}")
      end
    end
  end
end
