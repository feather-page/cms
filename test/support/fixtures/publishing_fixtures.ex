defmodule Feather.PublishingFixtures do
  @moduledoc """
  Test helpers for deployment targets. All take a scope with a site, which
  can have one target.
  """

  def deployment_target_fixture(scope, attrs \\ %{}) do
    {:ok, target} =
      Feather.Publishing.create_target(
        scope,
        Enum.into(attrs, %{
          provider: "ftps",
          config: %{
            "host" => "ftp.example.com",
            "user" => "u1",
            "password" => "secret",
            "path" => "/site"
          }
        })
      )

    target
  end
end
