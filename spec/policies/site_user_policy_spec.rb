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

  permissions :destroy? do
    context 'for a superadmin' do
      it 'returns true' do
        superadmin = build(:user, :superadmin)
        site_user = create(:site_user)

        expect(described_class).to permit(superadmin, site_user)
      end
    end

    context 'for a site user' do
      it 'returns true if the user is the same' do
        user = create(:user)
        site = create(:site, users: [user])

        site_user = create(:site_user, site:)

        expect(described_class).to permit(user, site_user)
      end

      it 'returns false if the user is different' do
        site_user = create(:site_user)
        other_user = create(:user)

        expect(described_class).not_to permit(other_user, site_user)
      end
    end

    context 'for a user that is the same as the site user' do
      it 'returns false' do
        site_user = create(:site_user)

        expect(described_class).not_to permit(site_user.user, site_user)
      end
    end

    context 'for an anonymous user' do
      it 'returns false' do
        site_user = create(:site_user)

        expect(described_class).not_to permit(nil, site_user)
      end
    end
  end
end
