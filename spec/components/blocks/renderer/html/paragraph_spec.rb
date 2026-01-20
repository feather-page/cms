describe Blocks::Renderer::Html::Paragraph do
  subject(:paragraph) { described_class }

  let(:block) do
    Blocks::Paragraph.new(id: 'JXyF2m2GZQ', text:)
  end

  describe '#to_html' do
    let(:paragraph_html) { paragraph.new(block).to_html }

    context 'for a simple paragraph' do
      let(:text) { 'Foo' }

      it 'returns html' do
        expect(paragraph_html).to eq('<p>Foo</p>')
      end
    end

    context 'for allowed inline tags' do
      let(:text) do
        [
          '<b>Hallo</b>',
          '<i>Welt</i>',
          '<u>Foo</u>',
          '<a href="https://example.com">Bar</a>'
        ].join(' ')
      end

      it 'returns the sanitized inline tags' do
        expect(paragraph_html).to eq("<p>#{text}</p>")
      end
    end

    context 'for disallowed inline tags' do
      let(:text) do
        [
          "<script>alert('foo')</script>",
          "<a href='javascript:alert(1)'>Bar</a>",
          "<u onclick='alert(1)' class='blub'>Foo</u>"
        ].join(' ')
      end

      it 'scrubs the html' do
        expect(paragraph_html).to eq("<p>alert('foo') <a>Bar</a> <u>Foo</u></p>")
      end
    end

    context 'for internal links with SGID' do
      let(:site) { create(:site) }
      let(:page) { create(:page, site:, title: 'About', slug: '/about') }
      let(:sgid) { page.to_sgid(expires_in: nil, for: 'internal_link').to_s }
      let(:text) { %(<a href="/old-slug" data-sgid="#{sgid}">About Page</a>) }

      before do
        Current.site = site
      end

      after do
        Current.reset
      end

      it 'resolves the link to current slug' do
        expect(paragraph_html).to eq('<p><a href="/about">About Page</a></p>')
      end

      it 'removes the data-sgid attribute' do
        expect(paragraph_html).not_to include('data-sgid')
      end

      context 'when slug changes' do
        before do
          page.update!(slug: '/new-about')
        end

        it 'resolves to the new slug' do
          expect(paragraph_html).to eq('<p><a href="/new-about">About Page</a></p>')
        end
      end

      context 'when target is deleted' do
        before do
          page.destroy!
        end

        it 'converts link to plain text' do
          expect(paragraph_html).to eq('<p>About Page</p>')
        end
      end

      context 'when target is a draft post' do
        let(:draft_post) { create(:post, site:, title: 'Draft', slug: '/draft', draft: true) }
        let(:sgid) { draft_post.to_sgid(expires_in: nil, for: 'internal_link').to_s }

        it 'converts link to plain text' do
          expect(paragraph_html).to eq('<p>About Page</p>')
        end

        context 'when render_drafts is true' do
          before do
            Current.render_drafts = true
          end

          it 'resolves the link' do
            expect(paragraph_html).to eq('<p><a href="/draft">About Page</a></p>')
          end
        end
      end

      context 'when target belongs to different site' do
        let(:other_site) { create(:site) }
        let(:other_page) { create(:page, site: other_site, slug: '/other') }
        let(:sgid) { other_page.to_sgid(expires_in: nil, for: 'internal_link').to_s }

        it 'converts link to plain text' do
          expect(paragraph_html).to eq('<p>About Page</p>')
        end
      end

      context 'when Current.site is not set' do
        before do
          Current.reset
        end

        it 'preserves the link with data-sgid' do
          expect(paragraph_html).to include('data-sgid')
        end
      end

      context 'with invalid SGID' do
        let(:text) { '<a href="/broken" data-sgid="invalid-sgid">Broken Link</a>' }

        it 'converts link to plain text' do
          expect(paragraph_html).to eq('<p>Broken Link</p>')
        end
      end
    end

    context 'for external links' do
      let(:text) { '<a href="https://example.com">External</a>' }

      before do
        Current.site = create(:site)
      end

      after do
        Current.reset
      end

      it 'preserves the link unchanged' do
        expect(paragraph_html).to eq('<p><a href="https://example.com">External</a></p>')
      end
    end
  end
end
