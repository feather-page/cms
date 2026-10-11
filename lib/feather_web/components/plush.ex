defmodule FeatherWeb.Plush do
  @moduledoc """
  The plush images of the admin for `<.plush>` and `<.empty_state plush="…">`
  from setzkasten: one transparent WebP per name in
  `priv/static/images/plush`, used in both themes. Named after the Lucide
  icon they stand in for. Plush is kept for the brand and the empty pages;
  every other symbol is a Lucide icon.

  The images are derived from Noto Emoji 3D (Google, Apache License 2.0);
  `LICENSE` and `NOTICE` next to them name the source and the changes.
  """
  @behaviour Setzkasten.Plush
  use FeatherWeb, :verified_routes

  @impl true
  def src("book-open", :light), do: ~p"/images/plush/book-open.webp"
  def src("feather", :light), do: ~p"/images/plush/feather.webp"
  def src("house", :light), do: ~p"/images/plush/house.webp"
  def src("rocket", :light), do: ~p"/images/plush/rocket.webp"
  def src(_name, _variant), do: nil
end
