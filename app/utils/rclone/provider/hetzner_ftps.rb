module Rclone
  module Provider
    class HetznerFtps < Base
      def rclone_target
        "hetzner-ftps:#{config.fetch('path')}"
      end

      def config_file_content
        <<~CONFIG
          [hetzner-ftps]
          type = ftp
          host = #{config.fetch('host')}
          user = #{config.fetch('user')}
          pass = #{obscured_password}
          port = 21
          explicit_tls = true
        CONFIG
      end

      private

      def email
        config.fetch('email')
      end

      def obscured_password
        @rclone.run(['obscure', config.fetch('password')]).fetch(:stdout)
      end
    end
  end
end
