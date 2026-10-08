defmodule Feather.Content.SlugTest do
  use ExUnit.Case, async: true

  alias Feather.Content.Slug

  describe "normalize/1" do
    test "adds a leading and removes a trailing slash" do
      assert Slug.normalize("about") == "/about"
      assert Slug.normalize("/about/") == "/about"
      assert Slug.normalize("about/me") == "/about/me"
      assert Slug.normalize("/") == "/"
    end

    test "turns blank slugs into nil" do
      assert Slug.normalize("") == nil
      assert Slug.normalize("   ") == nil
      assert Slug.normalize(nil) == nil
    end
  end

  describe "reserved?/1" do
    test "reserves generated prefixes and artifacts" do
      for slug <-
            ~w(/images /images/x /page/2 /posts /posts/abc /projects/x /feed.xml /robots.txt /sitemap.xml) do
        assert Slug.reserved?(slug), "expected #{slug} to be reserved"
      end
    end

    test "allows everything else" do
      for slug <- ~w(/about /imagesque /blog/posts /feed) do
        refute Slug.reserved?(slug), "expected #{slug} not to be reserved"
      end
    end
  end

  describe "from_title/1 and suggest/2" do
    test "slugifies like the Rails SlugGenerator" do
      assert Slug.from_title("Hello World") == "/hello-world"
      assert Slug.from_title("a/b c") == "/ab-c"
      assert Slug.from_title("  Many   Spaces ") == "/many-spaces"
      assert Slug.from_title("Über") == "/-ber"
      assert Slug.from_title("") == ""
    end

    test "appends a counter while the slug is taken" do
      taken = MapSet.new(["/hello", "/hello1"])
      assert Slug.suggest("Hello", &MapSet.member?(taken, &1)) == "/hello2"
      assert Slug.suggest("Hello", fn _ -> false end) == "/hello"
    end

    test "never suggests reserved slugs" do
      assert Slug.suggest("Posts", fn _ -> false end) == "/posts1"
      assert Slug.suggest("", fn _ -> false end) == ""
    end
  end
end
