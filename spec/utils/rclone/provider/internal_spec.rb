describe Rclone::Provider::Internal do
  subject(:target) { described_class.new(deployment_target) }

  let(:deployment_target) { create(:deployment_target, :staging) }

  describe '#rclone_target' do
    it 'returns a target matching the config file' do
      skip 'Requires STAGING_SITES_PATH' unless ENV.key?('STAGING_SITES_PATH')

      static_site_path = ENV.fetch('STAGING_SITES_PATH')
      expect(target.rclone_target).to eq "internal:/#{static_site_path}/#{deployment_target.public_hostname}"
    end

    it 'returns a simple internal conifg file' do
      expect(target.config_file_content).to eq <<~CONFIG
        [internal]
        type = local
      CONFIG
    end
  end
end
