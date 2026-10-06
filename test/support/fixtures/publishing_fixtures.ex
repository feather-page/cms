defmodule Feather.PublishingFixtures do
  @moduledoc """
  Test helpers for deployment targets. All take a scope with a site.
  """

  def deployment_target_fixture(scope, attrs \\ %{}) do
    {:ok, target} =
      Feather.Publishing.create_target(
        scope,
        Enum.into(attrs, %{
          type: "production",
          provider: "hetzner_ftps",
          public_hostname: "www#{System.unique_integer([:positive])}.example.com",
          config: %{"host" => "ftp.example.com", "user" => "u1", "password" => "secret"}
        })
      )

    target
  end
end
