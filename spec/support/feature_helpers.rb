module FeatureHelpers
  def as_user
    user = create(:user)
    login_as(user)
    yield(user)
  end

  def as_site_user
    as_user do |user|
      site = create(:site, users: [user])
      yield(user, site)
    end
  end

  def as_site_admin
    user = create(:user, :site_admin)
    login_as(user)
    yield(user)
  end

  def as_superadmin
    user = create(:user, :superadmin)
    login_as(user)
    yield(user)
  end

  def login_as(user)
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # rubocop:enable RSpec/AnyInstance
  end

  def within_turbo_frame_for(object, &)
    within("##{dom_id(object)}", &)
  end
end
