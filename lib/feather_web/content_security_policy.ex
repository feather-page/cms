defmodule FeatherWeb.ContentSecurityPolicy do
  @moduledoc """
  The admin's Content-Security-Policy: own scripts only, so injected markup
  cannot run; the block editor needs inline styles.
  """

  @doc """
  The policy as header value. Forms submit to our own origin and to the
  `:form_action` origins; browsers also check where a submitted form
  redirects against them. Only our own pages may frame a page, unless
  `:frame_ancestors` says otherwise (`"'none'"`).
  """
  @spec header(keyword()) :: String.t()
  def header(opts \\ []) do
    form_action = Keyword.get(opts, :form_action, [])
    frame_ancestors = Keyword.get(opts, :frame_ancestors, "'self'")

    Enum.join(
      [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' 'unsafe-inline'",
        "font-src 'self' data:",
        "img-src 'self' data: blob: https:",
        "connect-src 'self'",
        "frame-src 'self' https:",
        "object-src 'none'",
        "base-uri 'self'",
        Enum.join(["form-action 'self'" | form_action], " "),
        "frame-ancestors #{frame_ancestors}"
      ],
      "; "
    )
  end
end
