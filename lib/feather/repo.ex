defmodule Feather.Repo do
  use Ecto.Repo,
    otp_app: :feather,
    adapter: Ecto.Adapters.SQLite3
end
