# Image files written by tests go to a scratch storage root.
storage_root = Application.fetch_env!(:feather, :storage_root)
File.rm_rf!(storage_root)
File.mkdir_p!(storage_root)

ExUnit.start(assert_receive_timeout: 1_000)
Ecto.Adapters.SQL.Sandbox.mode(Feather.Repo, :manual)
