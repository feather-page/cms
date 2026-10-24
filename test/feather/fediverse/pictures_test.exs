defmodule Feather.Fediverse.PicturesTest do
  use Feather.DataCase

  import Plug.Conn

  alias Feather.Fediverse
  alias Feather.Fediverse.Pictures
  alias Feather.Publishing.Deploy
  alias Vix.Vips.{Image, MutableImage, Operation}

  @moduletag :capture_log

  defp kept_size(name) do
    {:ok, {image, _flags}} = Operation.webpload(Pictures.path(name), n: -1)
    {Image.width(image), Image.height(image)}
  end

  defp kept_names do
    case File.ls(Path.dirname(Pictures.path("000000000000.webp"))) do
      {:ok, names} -> Enum.sort(names)
      {:error, :enoent} -> []
    end
  end

  # A header in front of a few bytes of pixels: libvips reads the size without decoding them.
  defp png_header(width, height) do
    chunk = fn type, data ->
      <<byte_size(data)::32, type::binary, data::binary, :erlang.crc32(type <> data)::32>>
    end

    <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>> <>
      chunk.("IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>) <>
      chunk.("IDAT", :zlib.compress(<<0, 0, 0, 0>>)) <> chunk.("IEND", "")
  end

  defp jpeg_header(width, height) do
    segment = fn marker, data -> <<0xFF, marker, byte_size(data) + 2::16, data::binary>> end
    components = for id <- 1..3, into: <<>>, do: <<id, 0x11, 0>>
    scan = for id <- 1..3, into: <<>>, do: <<id, 0>>

    <<0xFF, 0xD8>> <>
      segment.(0xC0, <<8, height::16, width::16, 3, components::binary>>) <>
      segment.(0xDA, <<3, scan::binary, 0, 63, 0>>) <> <<0, 0, 0xFF, 0xD9>>
  end

  defp webp_header(width, height) do
    size = Bitwise.bsl(height - 1, 14) + width - 1
    vp8l = <<0x2F, size::little-32, 0, 0, 0>>
    chunk = <<"VP8L", byte_size(vp8l)::little-32, vp8l::binary>>
    <<"RIFF", byte_size(chunk) + 4::little-32, "WEBP", chunk::binary>>
  end

  defp gif_header(width, height) do
    screen = <<width::little-16, height::little-16, 0, 0, 0>>
    frame = <<0x2C, 0::16, 0::16, width::little-16, height::little-16, 0>>
    "GIF89a" <> screen <> frame <> <<2, 2, 0x4C, 0x01, 0, 0x3B>>
  end

  defp animated_gif do
    {:ok, frames} = Operation.black(64, 96, bands: 3)
    {:ok, frames} = Operation.cast(frames, :VIPS_FORMAT_UCHAR)

    {:ok, frames} =
      Image.mutate(frames, fn image -> MutableImage.set(image, "page-height", :gint, 48) end)

    {:ok, gif} = Image.write_to_buffer(frames, ".gif")
    gif
  end

  describe "put/1" do
    test "keeps a JPEG, PNG, WebP or GIF as a square webp of 96 pixels under a new name" do
      for suffix <- [".jpg", ".png", ".webp", ".gif"] do
        assert {:ok, name} = Pictures.put(test_image_binary(200, 120, suffix)), suffix
        assert name =~ ~r/\A[0-9A-Za-z]{12}\.webp\z/
        assert kept_size(name) == {96, 96}
        assert binary_part(File.read!(Pictures.path(name)), 8, 4) == "WEBP"
      end
    end

    test "refuses a file whose magic bytes are not JPEG, PNG, WebP or GIF before libvips opens it" do
      before = kept_names()

      for picture <- [
            test_image_binary(64, 48, ".tif"),
            ~s(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>),
            "P3\n1 1\n255\n0 0 0\n",
            ""
          ] do
        assert Pictures.put(picture) == {:error, :unsupported_format}
      end

      assert kept_names() == before
    end

    test "refuses a picture whose header names more than 4096 × 4096 pixels" do
      assert Pictures.put(png_header(4097, 4096)) == {:error, :too_many_pixels}
      assert Pictures.put(png_header(100_000, 100_000)) == {:error, :too_many_pixels}

      for header <- [&jpeg_header/2, &webp_header/2, &gif_header/2] do
        assert Pictures.put(header.(4097, 4096)) == {:error, :too_many_pixels}
        assert Pictures.put(header.(16_383, 16_383)) == {:error, :too_many_pixels}
      end
    end

    test "takes the first frame of an animation only" do
      assert {:ok, name} = Pictures.put(animated_gif())
      assert kept_size(name) == {96, 96}
    end
  end

  describe "fetch/2" do
    setup do
      %{site: fediverse_site_fixture(%{domain: "timon.blog"})}
    end

    defp serve(body) do
      Req.Test.stub(Feather.Fediverse, fn conn -> send_resp(conn, 200, body) end)
    end

    test "downloads and keeps the picture of an account", %{site: site} do
      serve(test_image_binary(48, 48, ".png"))
      account = remote_account_fixture(%{picture_url: "https://files.mastodon.example/ana.png"})

      assert name = Pictures.fetch(site, account)
      assert kept_size(name) == {96, 96}
    end

    test "keeps nothing for an account without a picture or a picture it refuses",
         %{site: site} do
      serve(test_image_binary(48, 48, ".tif"))

      refute Pictures.fetch(site, remote_account_fixture())

      refute Pictures.fetch(
               site,
               remote_account_fixture(%{picture_url: "https://files.mastodon.example/ana.tif"})
             )
    end

    test "deletes a kept picture" do
      {:ok, name} = Pictures.put(test_image_binary())

      assert Pictures.delete(name) == :ok
      refute File.exists?(Pictures.path(name))
      assert Pictures.delete(nil) == :ok
    end
  end

  describe "a picture no approved reply uses" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      scope = fediverse_scope_fixture()
      reply = approved_reply_fixture(scope.site, post_fixture(scope))
      online = Path.join(tmp_dir, "online")

      %{
        scope: scope,
        target: deployment_target_fixture(scope),
        reply: reply,
        picture: Pictures.path(reply.approved_picture),
        online: online,
        online_picture: Path.join([online, "images", "replies", reply.approved_picture])
      }
    end

    # Runs `meanwhile` while the deploy uploads the export.
    defp deploy(c, meanwhile \\ fn -> :ok end, sync_result \\ {:ok, ""}) do
      Deploy.run(c.target,
        brotli: false,
        runner: fn
          ["obscure", "-"], opts ->
            {:ok, "obscured-" <> String.trim_trailing(opts[:input], "\n")}

          ["sync", "--config", _config, source, _remote], _opts ->
            meanwhile.()
            File.rm_rf!(c.online)
            File.cp_r!(source, c.online)
            sync_result
        end
      )
    end

    test "is kept until a deploy has succeeded", c do
      {:ok, _hidden} = Fediverse.hide_reply(c.scope, c.reply)
      assert File.regular?(c.picture)

      assert {:error, _message} = deploy(c, fn -> :ok end, {:error, "rclone failed"})
      assert File.regular?(c.picture)

      assert deploy(c) == {:ok, :deployed}
      refute File.exists?(c.picture)
      refute File.exists?(c.online_picture)
      assert Pictures.unused(c.scope.site) == []
    end

    test "is still there for a deploy that is running while its reply is hidden", c do
      test_pid = self()

      hide = fn ->
        {:ok, _hidden} = Fediverse.hide_reply(c.scope, c.reply)
        send(test_pid, {:kept_meanwhile, File.regular?(c.picture)})
      end

      assert deploy(c, hide) == {:ok, :deployed}

      assert_received {:kept_meanwhile, true}
      assert File.regular?(c.online_picture)
      refute File.exists?(c.picture)
    end
  end
end
