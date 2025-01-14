class SiteUserInvitation < ApplicationRecord
  belongs_to :site
  belongs_to :inviting_user, class_name: 'User'
end
