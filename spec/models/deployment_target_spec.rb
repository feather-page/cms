require "rails_helper"

RSpec.describe DeploymentTarget do
  let(:target) { create(:deployment_target, :staging) }

  describe "#acquire_deploy_lock!" do
    it "returns true and sets deploying to true when not locked" do
      expect(target.acquire_deploy_lock!).to be true
      expect(target.reload.deploying?).to be true
    end

    it "returns false when already locked" do
      target.update!(deploying: true)

      expect(target.acquire_deploy_lock!).to be false
    end

    it "returns false on concurrent lock attempt (StaleObjectError)" do
      # Simulate: another thread acquired the lock between reload and update
      allow(target).to receive(:update!).and_raise(ActiveRecord::StaleObjectError.new(target))

      expect(target.acquire_deploy_lock!).to be false
    end
  end

  describe "#release_deploy_lock!" do
    it "sets deploying to false and resets lock_version" do
      target.update!(deploying: true)

      target.release_deploy_lock!

      target.reload
      expect(target.deploying?).to be false
      expect(target.lock_version).to eq(0)
    end

    it "succeeds even with stale in-memory state" do
      stale_target = DeploymentTarget.find(target.id)
      target.update_columns(deploying: true, lock_version: 5)

      # stale_target has old lock_version — update_columns bypasses optimistic locking
      stale_target.release_deploy_lock!

      target.reload
      expect(target.deploying?).to be false
    end
  end
end
