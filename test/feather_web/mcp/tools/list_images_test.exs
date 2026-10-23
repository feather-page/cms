defmodule FeatherWeb.MCP.Tools.ListImagesTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias FeatherWeb.MCP.Tools.ListImages

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "lists the site's images, newest first", %{site_scope: site_scope, scope: scope} do
    older = image_fixture(site_scope)
    newer = image_fixture(site_scope, %{source_url: "https://photos.example/fog.png"})
    image_fixture(site_scope_fixture())

    assert ListImages.call(scope, %{"site" => "notes.example"}) ==
             {:ok,
              %{
                images: [
                  %{
                    id: newer.public_id,
                    filename: "photo.png",
                    alt: "",
                    width: 64,
                    height: 48,
                    source_url: "https://photos.example/fog.png"
                  },
                  %{
                    id: older.public_id,
                    filename: "photo.png",
                    alt: "",
                    width: 64,
                    height: 48,
                    source_url: nil
                  }
                ]
              }}
  end
end
