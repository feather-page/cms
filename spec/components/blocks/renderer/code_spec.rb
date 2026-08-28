# frozen_string_literal: true

describe Blocks::Renderer::Code do
  subject(:renderer) { described_class.new(block, routes:) }

  let(:block) { instance_double(Blocks::Code, language: 'ruby', code: 'puts bla') }
  let(:routes) { instance_double(StaticSite::Routes) }

  describe '#render' do
    it 'renders the code block as HTML' do
      expect(renderer.to_html).to eq('<pre><code>puts bla</code></pre>')
    end
  end
end