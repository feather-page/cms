module Rclone
  class Error < StandardError; end

  PROVIDERS = {
    fastmail: Provider::Fastmail,
    internal: Provider::Internal,
    hetzner_ftps: Provider::HetznerFtps
  }.freeze
end
