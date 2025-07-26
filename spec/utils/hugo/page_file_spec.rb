require 'spec_helper'

describe Hugo::PageFile do
  subject(:page_file) { described_class.new(page, deployment_target) }

  let(:page) { create(:page) }
  let(:deployment_target) { create(:deployment_target, :staging, site: page.site) }

  describe '#content' do
    let!(:book) { create(:book, site: page.site) }

    context 'when the page is of type books and the site has books' do
      let(:page) { create(:page, :books) }

      it 'includes the books' do
        expect(page_file.content).to include(book.title)
      end
    end

    context 'when the page is of type default' do
      it 'does not include the books' do
        expect(described_class.new(page, deployment_target).content).not_to include(book.title)
      end
    end
  end
end
