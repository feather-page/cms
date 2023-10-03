require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MeerkatCamp
  class Application < Rails::Application
    config.load_defaults 7.1
    # Initialize configuration defaults for originally generated Rails version.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.eager_load_paths << Rails.root.join('app/utils')
    config.eager_load_paths << Rails.root.join('app/inertactions')

    config.active_job.queue_adapter = :sidekiq

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('SMTP_ADDRESS', 'localhost'),
      port: ENV.fetch('SMTP_PORT', '25'),
      user_name: ENV.fetch('SMTP_USERNAME', nil),
      password: ENV.fetch('SMTP_PASSWORD', nil)
    }
    config.action_mailer.raise_delivery_errors = false

    # Do not wrap field errors in action view
    config.action_view.field_error_proc = proc { |html_tag, _instance| html_tag }

    config.session_store :cookie_store, key: '_meerkat_camp_session', expire_after: 1.month

    config.active_storage.variant_processor = :vips
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # Initialize encrypted attributes
    config.active_record.encryption.primary_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY', nil)
    config.active_record.encryption.deterministic_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY', nil)
    config.active_record.encryption.key_derivation_salt = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT', nil)
  end
end
