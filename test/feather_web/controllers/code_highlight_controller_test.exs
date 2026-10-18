defmodule FeatherWeb.CodeHighlightControllerTest do
  use FeatherWeb.ConnCase

  alias Feather.FakeChroma

  setup [:register_and_log_in_user, :create_site_for_user]

  defp highlight(conn, site, params),
    do: post(conn, ~p"/sites/#{site.public_id}/code/highlight", params)

  test "returns the highlighted HTML of the code", %{conn: conn, site: site} do
    FakeChroma.install()

    assert json_response(highlight(conn, site, %{code: "puts 1", language: "ruby"}), 200) == %{
             "html" => FakeChroma.html("puts 1")
           }

    assert_received {:chroma_highlighted, "ruby", "puts 1"}
  end

  test "returns null for code that is not highlighted", %{conn: conn, site: site} do
    FakeChroma.install()

    for params <- [
          %{code: "+[-]", language: "brainfuck"},
          %{code: "x", language: "plaintext"},
          %{code: "", language: "ruby"}
        ] do
      assert json_response(highlight(conn, site, params), 200) == %{"html" => nil}
    end

    refute_received {:chroma_highlighted, _lexer, _code}
  end

  @tag :capture_log
  test "returns null when chroma fails", %{conn: conn, site: site} do
    FakeChroma.install(:missing)

    assert json_response(highlight(conn, site, %{code: "puts 1", language: "ruby"}), 200) == %{
             "html" => nil
           }
  end

  test "rejects a request without code or language", %{conn: conn, site: site} do
    FakeChroma.install()

    for params <- [%{}, %{code: "x"}, %{language: "ruby"}, %{code: 1, language: "ruby"}] do
      assert %{"error" => _} = json_response(highlight(conn, site, params), 400)
    end

    refute_received {:chroma_highlighted, _lexer, _code}
  end

  test "denies access to sites the user is not a member of", %{conn: conn} do
    FakeChroma.install()

    assert_error_sent 404, fn ->
      highlight(conn, site_fixture(), %{code: "puts 1", language: "ruby"})
    end

    refute_received {:chroma_highlighted, _lexer, _code}
  end
end
