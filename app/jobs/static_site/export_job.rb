module StaticSite
  class ExportJob < ApplicationJob
    MAX_LOCK_RETRIES = 60

    queue_as :default

    def perform(deployment_target, deployer: Rclone::Deployer, noticer: Noticer)
      @deployment_target = deployment_target
      @deployer = deployer
      @noticer = noticer

      return retry_or_give_up unless acquire_lock

      @sink = FileSink.new(deployment_target.build_path)
      build_and_publish
      deploy_and_notify
    ensure
      @sink&.discard!
      release_lock
    end

    private

    attr_reader :deployment_target, :sink

    def acquire_lock
      @lock_acquired = deployment_target.acquire_deploy_lock!
    end

    def release_lock
      deployment_target.release_deploy_lock! if @lock_acquired
    end

    def retry_or_give_up
      return retry_job(wait: 5.seconds) if executions < MAX_LOCK_RETRIES

      Rails.logger.warn(
        "Deploy lock for target #{deployment_target.id} stuck — giving up after #{MAX_LOCK_RETRIES} retries"
      )
    end

    def build_and_publish
      export
      precompress
      publish
    end

    def export
      Export.new(site: deployment_target.site, routes: Routes.for(deployment_target), sink:).run
    end

    def precompress
      PrecompressJob.perform_now(sink.dir)
    end

    # Replaces the deployed directory with what this run built. The export never
    # touches the live directory, so a failure above leaves it untouched.
    def publish
      destination = deployment_target.source_dir.chomp("/")

      FileUtils.rm_rf(destination)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.mv(sink.dir, destination)
    end

    def deploy_and_notify
      @deployer.deploy(deployment_target)
      @noticer.new(deployment_target.site).notice(
        "Site built. <a href='https://#{deployment_target.public_hostname}'>Preview</a>"
      )
    end
  end
end
