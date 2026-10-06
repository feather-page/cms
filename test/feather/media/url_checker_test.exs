defmodule Feather.Media.UrlCheckerTest do
  use ExUnit.Case, async: true

  alias Feather.Media.UrlChecker

  test "accepts public http and https URLs on the default ports" do
    for url <- [
          "https://images.unsplash.com/photo.jpg",
          "http://example.com/a.png",
          "https://example.com:443/a.png",
          "http://93.184.216.34/a.png",
          "http://[2606:2800:220:1:248:1893:25c8:1946]/a.png"
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
          "http://100.64.0.1/a.png",
          "http://224.0.0.1/a.png",
          "http://255.255.255.255/a.png",
          "http://[::]/a.png",
          "http://[::1]/a.png",
          "http://[::127.0.0.1]/a.png",
          "http://[fd00::1]/a.png",
          "http://[fe80::1]/a.png",
          "http://[ff02::1]/a.png",
          "http://[::ffff:10.0.0.1]/a.png",
          "http://[0:0:0:0:0:ffff:127.0.0.1]/a.png",
          "http://[64:ff9b::7f00:1]/a.png",
          "http://[2002:7f00:1::1]/a.png"
        ] do
      assert {:error, "Forbidden IP" <> _} = UrlChecker.check(url), url
    end
  end

  test "rejects IPv4 addresses in non-canonical forms" do
    for url <- [
          "http://2130706433/",
          "http://127.1/",
          "http://0177.0.0.1/",
          "http://0x7f.0.0.1/",
          "http://0x7f000001/",
          "http://010.0.0.1/",
          "http://93.184.216.034/",
          "http://1.2.3.4.5/",
          "http://example.123/"
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

  describe "public_address?/1" do
    test "public addresses" do
      for ip <- [
            {93, 184, 216, 34},
            {8, 8, 8, 8},
            {100, 63, 255, 255},
            {172, 32, 0, 1},
            {0x2606, 0x2800, 0x220, 1, 0x248, 0x1893, 0x25C8, 0x1946},
            {0, 0, 0, 0, 0, 0xFFFF, 0x5DB8, 0xD822},
            {0x64, 0xFF9B, 0, 0, 0, 0, 0x0808, 0x0808}
          ] do
        assert UrlChecker.public_address?(ip), inspect(ip)
      end
    end

    test "private, reserved and special addresses" do
      for ip <- [
            {0, 1, 2, 3},
            {10, 1, 2, 3},
            {100, 64, 0, 1},
            {127, 0, 0, 1},
            {169, 254, 169, 254},
            {172, 31, 255, 255},
            {192, 0, 0, 170},
            {192, 0, 2, 1},
            {192, 168, 0, 1},
            {198, 18, 0, 1},
            {198, 51, 100, 1},
            {203, 0, 113, 1},
            {224, 0, 0, 251},
            {240, 0, 0, 1},
            {255, 255, 255, 255},
            {0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 1},
            {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 1},
            {0, 0, 0, 0, 0, 0, 0x0A00, 1},
            {0x64, 0xFF9B, 0, 0, 0, 0, 0xC0A8, 1},
            {0x64, 0xFF9B, 1, 0, 0, 0, 0, 1},
            {0x2002, 0x0A00, 1, 0, 0, 0, 0, 1},
            {0x2001, 0, 0x4136, 0xE378, 0x8000, 0x63BF, 0x3FFF, 0xFDD2},
            {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1},
            {0xFC00, 0, 0, 0, 0, 0, 0, 1},
            {0xFE80, 0, 0, 0, 0, 0, 0, 1},
            {0xFEC0, 0, 0, 0, 0, 0, 0, 1},
            {0xFF02, 0, 0, 0, 0, 0, 0, 1},
            {0x100, 0, 0, 0, 0, 0, 0, 1}
          ] do
        refute UrlChecker.public_address?(ip), inspect(ip)
      end
    end
  end

  describe "resolve/2" do
    test "returns the address of a host whose addresses are all public" do
      assert UrlChecker.resolve("images.example.com", 1000) == {:ok, {93, 184, 215, 14}}
      assert UrlChecker.resolve("8.8.8.8.nip.io", 1000) == {:ok, {8, 8, 8, 8}}
      assert UrlChecker.resolve("93.184.216.34", 1000) == {:ok, {93, 184, 216, 34}}
    end

    test "refuses hosts with a private address or none" do
      assert UrlChecker.resolve("127.0.0.1.nip.io", 1000) == {:error, :forbidden_address}

      assert UrlChecker.resolve("private-and-public.example", 1000) ==
               {:error, :forbidden_address}

      assert UrlChecker.resolve("unresolvable.example", 1000) == {:error, :unresolvable}
    end

    test "the system resolver returns IPv4 and IPv6 addresses" do
      assert {:ok, addresses} = UrlChecker.system_resolve("localhost", 1000)
      assert {127, 0, 0, 1} in addresses
      refute Enum.any?(addresses, &UrlChecker.public_address?/1)
    end
  end
end
