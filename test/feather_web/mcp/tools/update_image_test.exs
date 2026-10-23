defmodule FeatherWeb.MCP.Tools.UpdateImageTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias Feather.Media
  alias FeatherWeb.MCP.Tools.UpdateImage

  setup do
    site_scope = site_scope_fixture(%{domain: "notes.example"})
    %{site_scope: site_scope, scope: Scope.for_user(site_scope.user)}
  end

  test "sets the alt text", %{site_scope: site_scope, scope: scope} do
    image = image_fixture(site_scope)

    assert {:ok, %{id: id, alt: "A lighthouse in fog"}} =
             UpdateImage.call(scope, %{
               "site" => "notes.example",
               "image" => image.public_id,
               "alt" => " A lighthouse in fog "
             })

    assert id == image.public_id
    assert Media.get_image!(site_scope, image.public_id).alt == "A lighthouse in fog"
  end

  test "an alt text that is too long is an error", %{site_scope: site_scope, scope: scope} do
    image = image_fixture(site_scope)

    assert UpdateImage.call(scope, %{
             "site" => "notes.example",
             "image" => image.public_id,
             "alt" => String.duplicate("a", 1001)
           }) == {:error, "Invalid image: alt should be at most 1000 character(s)"}
  end

  test "an image of another site is missing", %{scope: scope} do
    theirs = image_fixture(site_scope_fixture())

    assert UpdateImage.call(scope, %{
             "site" => "notes.example",
             "image" => theirs.public_id,
             "alt" => "Mine"
           }) ==
             {:error,
              "There is no image #{theirs.public_id} on notes.example. " <>
                "list_images lists its images."}

    assert Repo.reload!(theirs).alt == ""
  end
end
