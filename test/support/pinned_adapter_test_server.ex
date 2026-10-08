defmodule Feather.PinnedAdapterTestServer do
  @moduledoc "The HTTP server of Feather.Media.PinnedAdapterTest."
  import Plug.Conn

  def init(opts), do: opts

  def call(%{request_path: "/big"} = conn, _opts) do
    conn = send_chunked(conn, 200)

    Enum.reduce_while(1..100, conn, fn _, conn ->
      case chunk(conn, :binary.copy("x", 1000)) do
        {:ok, conn} -> {:cont, conn}
        {:error, _} -> {:halt, conn}
      end
    end)
  end

  def call(%{request_path: "/slow"} = conn, _opts) do
    receive do
    after
      1_000 -> send_resp(conn, 200, "late")
    end
  end

  def call(conn, _opts) do
    send_resp(
      conn,
      200,
      "host=#{get_req_header(conn, "host")} path=#{conn.request_path}?#{conn.query_string}"
    )
  end
end
