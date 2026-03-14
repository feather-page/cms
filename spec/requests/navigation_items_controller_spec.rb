require "rails_helper"

describe NavigationItemsController do
  let(:user) { create(:user, :site_admin) }
  let(:site) { user.sites.first }

  before { login_as(user) }

  describe "POST #create" do
    it "adds a page to the navigation" do
      page = create(:page, site: site)

      expect {
        post navigation_items_path, params: { site_id: site.to_param, page_id: page.id }
      }.to change(NavigationItem, :count).by(1)

      expect(site.main_navigation.navigation_items.map(&:page)).to include(page)
    end

    it "does not duplicate if page is already in navigation" do
      page = create(:page, site: site)
      site.main_navigation.add(page)

      expect {
        post navigation_items_path, params: { site_id: site.to_param, page_id: page.id }
      }.not_to change(NavigationItem, :count)
    end

    it "returns turbo stream redirect" do
      page = create(:page, site: site)

      post navigation_items_path, params: { site_id: site.to_param, page_id: page.id }

      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "DELETE #destroy" do
    it "removes the page from navigation" do
      page = create(:page, site: site)
      site.main_navigation.add(page)
      nav_item = NavigationItem.find_by(page: page)

      expect {
        delete navigation_item_path(nav_item)
      }.to change(NavigationItem, :count).by(-1)
    end

    it "returns turbo stream redirect" do
      page = create(:page, site: site)
      site.main_navigation.add(page)
      nav_item = NavigationItem.find_by(page: page)

      delete navigation_item_path(nav_item)

      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "PATCH #move_up" do
    it "moves the navigation item up" do
      page1 = create(:page, site: site)
      page2 = create(:page, site: site)
      site.main_navigation.add(page1)
      site.main_navigation.add(page2)
      nav_item2 = NavigationItem.find_by(page: page2)

      patch move_up_navigation_item_path(nav_item2)

      expect(response).to be_successful

      positions = site.main_navigation.navigation_items.reload.order(:position).map(&:page_id)
      expect(positions).to eq([page2.id, page1.id])
    end

    it "returns turbo stream redirect" do
      page1 = create(:page, site: site)
      page2 = create(:page, site: site)
      site.main_navigation.add(page1)
      site.main_navigation.add(page2)
      nav_item2 = NavigationItem.find_by(page: page2)

      patch move_up_navigation_item_path(nav_item2)

      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "PATCH #move_down" do
    it "moves the navigation item down" do
      page1 = create(:page, site: site)
      page2 = create(:page, site: site)
      site.main_navigation.add(page1)
      site.main_navigation.add(page2)
      nav_item1 = NavigationItem.find_by(page: page1)

      patch move_down_navigation_item_path(nav_item1)

      expect(response).to be_successful

      positions = site.main_navigation.navigation_items.reload.order(:position).map(&:page_id)
      expect(positions).to eq([page2.id, page1.id])
    end

    it "returns turbo stream redirect" do
      page1 = create(:page, site: site)
      page2 = create(:page, site: site)
      site.main_navigation.add(page1)
      site.main_navigation.add(page2)
      nav_item1 = NavigationItem.find_by(page: page1)

      patch move_down_navigation_item_path(nav_item1)

      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end
end
