describe SiteUserPolicy do
  describe 'scope' do
    context 'for a superadmin' do
      it 'returns all users' do
        superadmin = build(:user, :superadmin)
        site_users = create_list(:site_user, 3)

        scope = SiteUserPolicy::Scope.new(superadmin, SiteUser).resolve

        expect(scope).to match_array(site_users)
      end
    end

    context 'for an anonymous user' do
      it 'returns no users' do
        _users = create_list(:site_user, 3)

        scope = SiteUserPolicy::Scope.new(nil, SiteUser).resolve

        expect(scope).to be_empty
      end
    end

    context 'for a site user' do
      it 'returns only users from the site' do
        site = create(:site)

        site_users = create_list(:site_user, 2, site:)
        other_users = create_list(:site_user, 2)

        scope = SiteUserPolicy::Scope.new(site_users.first.user, SiteUser).resolve

        expect(scope).to match_array(site_users)
        expect(scope).not_to include(*other_users)
      end
    end
  end
end
