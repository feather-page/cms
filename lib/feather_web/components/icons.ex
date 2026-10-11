defmodule FeatherWeb.Icons do
  @moduledoc """
  The Lucide icons of the admin, compiled from the SVG files in
  `assets/vendor/lucide` (lucide-static, ISC licence). `<.icon name="…">`
  from `setzkasten` looks names up here first, then in the icons the
  library ships itself (`Setzkasten.Lucide`); an unknown name raises.

  To add an icon, copy `icons/<name>.svg` from lucide-static into the
  directory. The social media brand icons are not Lucide icons, see
  `FeatherWeb.CoreComponents.brand_icon/1`.
  """
  use Setzkasten.Icons, path: "assets/vendor/lucide"
end
