describe 'Administration of deployment targets' do
  describe 'editing a deployment target' do
    it 'updated the deployment target' do
      as_user do |user|
        site = create(:site, users: [user])
        deployment_target = create(:deployment_target, site:)

        visit site_deployment_targets_path(site)
        click_on 'Edit'

        deployment_target_attributes = attributes_for(:deployment_target)
        fill_in 'Public hostname', with: deployment_target_attributes[:public_hostname]

        click_on 'Update Deployment target'

        expect(page).to have_content('Deployment target was successfully updated.')
        expect(deployment_target.reload.public_hostname).to eq(deployment_target_attributes[:public_hostname])
      end
    end
  end
end
