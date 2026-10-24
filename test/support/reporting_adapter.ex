defmodule Feather.ReportingAdapter do
  @moduledoc """
  A `Req` adapter for tests that takes the place of
  `Feather.Media.PinnedAdapter`: it tells the calling process what the
  pinned connection of each request would get
  (`{:connecting, host, request.private.feather_pinned}`) and answers with
  the `Req.Test` stubs of `Feather.Fediverse`
  (`config :feather, :fediverse_req_options, adapter: Feather.ReportingAdapter`).
  """

  def run(%Req.Request{} = request) do
    send(self(), {:connecting, request.url.host, request.private.feather_pinned})

    Req.Plug.run(%{
      request
      | options: Map.put(request.options, :plug, {Req.Test, Feather.Fediverse})
    })
  end
end
