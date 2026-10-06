defmodule Feather.Mailer do
  use Swoosh.Mailer, otp_app: :feather

  @doc """
  The sender of all application emails, `config :feather, :mail_from`.
  """
  def from, do: Application.fetch_env!(:feather, :mail_from)
end
