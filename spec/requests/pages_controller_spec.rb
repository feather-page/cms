require "rails_helper"

describe PagesController do
  include_context "authenticated user"

  describe "GET #index" do
    it "returns successful response" do
      create_list(:page, 2, site: site)
      get site_pages_path(site)
      expect(response).to be_successful
    end

    it "shows all pages" do
      pages = create_list(:page, 2, site: site)
      get site_pages_path(site)
      pages.each { |page| expect(response.body).to include(page.title) }
    end

    it "does not show pages from other sites" do
      other_site = create(:site)
      create(:page, site: other_site, title: "Other Site Page")

      get site_pages_path(site)
      expect(response.body).not_to include("Other Site Page")
    end
  end

  describe "GET #new" do
    it "returns successful response" do
      get new_site_page_path(site)
      expect(response).to be_successful
    end
  end

  describe "GET #edit" do
    let(:page) { create(:page, site: site) }

    it "returns successful response" do
      get edit_site_page_path(site, page)
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      { page: { title: "New Page", slug: "new-page" } }
    end

    context "with valid parameters" do
      it "creates a new page" do
        expect do
          post site_pages_path(site), params: valid_params
        end.to change(Page, :count).by(1)
      end

      it "assigns the page to the current site" do
        post site_pages_path(site), params: valid_params
        expect(Page.last.site).to eq(site)
      end

      it "returns turbo stream redirect" do
        post site_pages_path(site), params: valid_params
        expect(response).to be_successful
        expect(response.body).to include("turbo-stream")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        { page: { title: "No Slug Page", slug: "" } }
      end

      it "does not create a page" do
        expect do
          post site_pages_path(site), params: invalid_params
        end.not_to change(Page, :count)
      end
    end
  end

  describe "PATCH #update" do
    let(:existing_page) { create(:page, site: site) }

    context "with valid parameters" do
      it "updates the page" do
        patch site_page_path(site, existing_page), params: { page: { title: "Updated Title" } }
        expect(existing_page.reload.title).to eq("Updated Title")
      end

      it "returns turbo stream redirect" do
        patch site_page_path(site, existing_page), params: { page: { title: "Updated Title" } }
        expect(response).to be_successful
        expect(response.body).to include("turbo-stream")
      end

      it "sets a success notice" do
        patch site_page_path(site, existing_page), params: { page: { title: "Updated Title" } }
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:existing_page) { create(:page, site: site) }

    it "deletes the page" do
      expect do
        delete site_page_path(site, existing_page)
      end.to change(Page, :count).by(-1)
    end

    it "returns successful response" do
      delete site_page_path(site, existing_page)
      expect(response).to be_successful
    end
  end
end
