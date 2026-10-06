defmodule Feather.Media.UrlCheckerTest do
  use ExUnit.Case, async: true

  alias Feather.Media.UrlChecker

  test "accepts public http and https URLs on the default ports" do
    for url <- [
          "https://images.unsplash.com/photo.jpg",
          "http://example.com/a.png",
          "https://example.com:443/a.png",
          "http://93.184.216.34/a.png"
        ] do
      assert {:ok, %URI{}} = UrlChecker.check(url), url
    end
  end

  test "rejects other schemes" do
    assert {:error, "Forbidden Schema" <> _} = UrlChecker.check("ftp://example.com/a.png")
    assert {:error, "Forbidden Schema" <> _} = UrlChecker.check("file:///etc/passwd")
  end

  test "rejects localhost and private, loopback and link-local addresses" do
    assert {:error, "Forbidden hostname" <> _} = UrlChecker.check("http://localhost/a.png")
    assert {:error, "Forbidden hostname" <> _} = UrlChecker.check("http://LOCALHOST./a.png")

    for url <- [
          "http://127.0.0.1/a.png",
          "http://10.0.0.1/a.png",
          "http://172.16.5.4/a.png",
          "http://192.168.1.1/a.png",
          "http://169.254.169.254/latest/meta-data",
          "http://0.0.0.0/a.png",
          "http://[::1]/a.png",
          "http://[fd00::1]/a.png",
          "http://[::ffff:10.0.0.1]/a.png"
        ] do
      assert {:error, "Forbidden IP" <> _} = UrlChecker.check(url), url
    end
  end

  test "rejects ports other than 80 and 443" do
    assert {:error, "Forbidden Port" <> _} = UrlChecker.check("http://example.com:8080/a.png")
    assert {:error, "Forbidden Port" <> _} = UrlChecker.check("https://example.com:22/")
  end

  test "rejects invalid URLs" do
    assert {:error, "Invalid URL" <> _} = UrlChecker.check("not a url")
    assert {:error, _} = UrlChecker.check(nil)
  end
end
