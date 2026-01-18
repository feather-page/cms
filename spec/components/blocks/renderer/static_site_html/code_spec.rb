describe Blocks::Renderer::StaticSiteHtml::Code do
  subject(:renderer) { described_class.new(block) }

  let(:block) { instance_double(Blocks::Code, language: 'ruby', code: 'puts bla') }

  describe '#render' do
    it 'renders the code block as HTML' do
      expect(renderer.to_html).to eq('<pre><code>puts bla</code></pre>')
    end
  end
end
