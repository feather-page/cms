defmodule Feather.StaticSite.Gettext do
  @moduledoc """
  The translations of the static site theme's own text (labels, dates),
  kept apart from the admin's `FeatherWeb.Gettext` in
  `priv/static_site/gettext`. Pages render in the site's language; the
  English msgids are the fallback for every language without a translation.
  """
  use Gettext.Backend, otp_app: :feather, priv: "priv/static_site/gettext"
end
