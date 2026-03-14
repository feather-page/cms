describe Rclone::Deployer do
  subject(:deployer) { described_class.new(provider, rclone:) }

  let(:rclone) { class_spy(Rclone::CommandRunner) }
  let(:site) { create(:site) }
  let(:provider) do
    instance_spy(
      Rclone::Provider::Internal,
      config_file_path: '/tmp/rclone/1.conf',
      rclone_target: 'fastmail:/files'
    )
  end

  describe '.deploy' do
    it 'deploys a site' do
      deployer.deploy

      expect(provider).to have_received(:write_config_file)
      expect(rclone).to have_received(:run).with(
        ["sync", "--config", provider.config_file_path, provider.source_dir, provider.rclone_target],
        { log: true }
      )
      expect(provider).to have_received(:delete_config_file)
    end
  end

  context 'when the deployment fails' do
    it 'ensures the config file is deleted' do
      allow(rclone).to receive(:run).and_raise(Rclone::Error)

      expect { deployer.deploy }.to raise_error(Rclone::Error)

      expect(provider).to have_received(:delete_config_file)
    end
  end

  describe '#deploy' do
    it 'picks the right provider and deploys' do
      skip 'Requires STAGING_SITES_PATH' unless ENV.key?('STAGING_SITES_PATH')

      target = create(:deployment_target, provider: 'internal')
      described_class.deploy(target, rclone:)

      expect(rclone).to have_received(:run)
    end
  end
end
