class ApplicationMailer < ActionMailer::Base
  before_action :set_default_url_options

  default from: 'no-reply@feather.page'
  layout 'mailer'

  private

  def set_default_url_options
    protocol = ENV.fetch('HTTPS') == 'true' ? 'https' : 'http'
    self.default_url_options = {
      host: "#{protocol}://#{ENV.fetch('BASE_HOSTNAME_AND_PORT')}"
    }
  end

  def user
    params[:user]
  end
end
