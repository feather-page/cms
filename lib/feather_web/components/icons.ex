defmodule FeatherWeb.Icons do
  @moduledoc """
  The icon set of the admin: Lucide icons (24×24, stroke based) ported from
  the Rails `IconComponent`, plus the social media brand icons from
  `priv/icons`. Old Bootstrap Icons names are mapped to Lucide names.

  Render icons with `FeatherWeb.CoreComponents.icon/1`.
  """

  # Bootstrap Icons name => Lucide name. Lucide names are accepted directly.
  @name_map %{
    "pen" => "pencil",
    "book" => "book-open",
    "box-seam-fill" => "package",
    "briefcase" => "briefcase",
    "caret-down-square" => "chevron-down",
    "caret-up-square" => "chevron-up",
    "envelope-check" => "mail-check",
    "eye" => "eye",
    "file-plus" => "file-plus",
    "files" => "files",
    "gear" => "settings",
    "globe" => "globe",
    "house" => "home",
    "house-add" => "house-plus",
    "houses" => "building-2",
    "pencil" => "pencil",
    "people-fill" => "users",
    "person-plus" => "user-plus",
    "rocket" => "rocket",
    "star" => "star",
    "trash" => "trash-2",
    "image" => "image",
    "upload" => "upload",
    "file-text" => "file-text",
    "box-seam" => "package",
    "mail" => "mail",
    "plus" => "plus",
    "minus" => "minus",
    "file" => "file"
  }

  # Lucide path data; each icon is a list of `d` attributes.
  @icons %{
    "search" => [
      "M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16z",
      "m21 21-4.3-4.3"
    ],
    "message-square-text" => [
      "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",
      "M13 8H7",
      "M17 12H7"
    ],
    "smile" => [
      "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
      "M8 14s1.5 2 4 2 4-2 4-2",
      "M9 9h.01",
      "M15 9h.01"
    ],
    "pencil" => [
      "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
      "m15 5 4 4"
    ],
    "book-open" => [
      "M12 7v14",
      "M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"
    ],
    "package" => [
      "M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z",
      "M12 22V12",
      "M3.3 7 12 12l8.7-5",
      "M7.5 4.27l9 5.15"
    ],
    "briefcase" => [
      "M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16",
      "M2 10a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2z"
    ],
    "chevron-down" => [
      "m6 9 6 6 6-6"
    ],
    "chevron-up" => [
      "m18 15-6-6-6 6"
    ],
    "mail-check" => [
      "M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8",
      "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7",
      "m16 19 2 2 4-4"
    ],
    "eye" => [
      "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0",
      "M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z"
    ],
    "eye-off" => [
      "M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49",
      "M14.084 14.158a3 3 0 0 1-4.242-4.242",
      "M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143",
      "m2 2 20 20"
    ],
    "ellipsis-vertical" => [
      "M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z",
      "M12 6a1 1 0 1 0 0-2 1 1 0 0 0 0 2z",
      "M12 20a1 1 0 1 0 0-2 1 1 0 0 0 0 2z"
    ],
    "key-round" => [
      "M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z",
      "M16.5 8a.5.5 0 1 0 0-1 .5.5 0 0 0 0 1z"
    ],
    "send" => [
      "M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z",
      "m21.854 2.147-10.94 10.939"
    ],
    "file-plus" => [
      "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z",
      "M14 2v4a2 2 0 0 0 2 2h4",
      "M12 18v-6",
      "M9 15h6"
    ],
    "files" => [
      "M20 7h-3a2 2 0 0 1-2-2V2",
      "M9 18a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h7l4 4v10a2 2 0 0 1-2 2z",
      "M3 7.6v12.8A1.6 1.6 0 0 0 4.6 22h9.8"
    ],
    "settings" => [
      "M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z",
      "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z"
    ],
    "globe" => [
      "M21.54 15H17a2 2 0 0 0-2 2v4.54",
      "M7 3.34V5a3 3 0 0 0 3 3a2 2 0 0 1 2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2c0-1.1.9-2 2-2h3.17",
      "M11 21.95V18a2 2 0 0 0-2-2a2 2 0 0 1-2-2v-1a2 2 0 0 0-2-2H1.05",
      "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z"
    ],
    "home" => [
      "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",
      "M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
    ],
    "house-plus" => [
      "M13.22 2.416a2 2 0 0 0-2.511.057l-7 5.999A2 2 0 0 0 3 10v9a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7.354",
      "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",
      "M15 6h6",
      "M18 3v6"
    ],
    "building-2" => [
      "M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z",
      "M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2",
      "M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2",
      "M10 6h4",
      "M10 10h4",
      "M10 14h4",
      "M10 18h4"
    ],
    "users" => [
      "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",
      "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
      "M22 21v-2a4 4 0 0 0-3-3.87",
      "M16 3.13a4 4 0 0 1 0 7.75"
    ],
    "user-plus" => [
      "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2",
      "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
      "M19 8v6",
      "M22 11h-6"
    ],
    "rocket" => [
      "M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z",
      "M12 15l-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z",
      "M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0",
      "M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"
    ],
    "star" => [
      "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"
    ],
    "trash-2" => [
      "M3 6h18",
      "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6",
      "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",
      "M10 11v6",
      "M14 11v6"
    ],
    "image" => [
      "M21 3H3a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z",
      "M8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z",
      "m21 15-5-5L5 21"
    ],
    "upload" => [
      "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4",
      "M17 8l-5-5-5 5",
      "M12 3v12"
    ],
    "circle-help" => [
      "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
      "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3",
      "M12 17h.01"
    ],
    "file-text" => [
      "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z",
      "M14 2v4a2 2 0 0 0 2 2h4",
      "M10 9H8",
      "M16 13H8",
      "M16 17H8"
    ],
    "mail" => [
      "M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z",
      "M22 7l-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"
    ],
    "plus" => [
      "M5 12h14",
      "M12 5v14"
    ],
    "minus" => [
      "M5 12h14"
    ],
    "file" => [
      "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z",
      "M14 2v4a2 2 0 0 0 2 2h4"
    ],
    "x" => [
      "M18 6 6 18",
      "m6 6 12 12"
    ],
    "check" => [
      "M20 6 9 17l-5-5"
    ],
    "info" => [
      "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
      "M12 16v-4",
      "M12 8h.01"
    ],
    "circle-alert" => [
      "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
      "M12 8v4",
      "M12 16h.01"
    ],
    "log-out" => [
      "m16 17 5-5-5-5",
      "M21 12H9",
      "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"
    ],
    "arrow-left" => [
      "m12 19-7-7 7-7",
      "M19 12H5"
    ],
    "loader-circle" => [
      "M21 12a9 9 0 1 1-6.219-8.56"
    ],
    "user" => [
      "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2",
      "M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"
    ],
    "circle-user" => [
      "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
      "M12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
      "M7 20.662V19a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1.662"
    ],
    "external-link" => [
      "M15 3h6v6",
      "M10 14 21 3",
      "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"
    ]
  }

  @fallback "circle-help"

  @doc "Resolves an icon name (Lucide or Bootstrap) to a Lucide name."
  @spec resolve(String.t()) :: String.t()
  def resolve(name), do: Map.get(@name_map, name, name)

  @doc "The path data of a Lucide icon, or nil if unknown."
  @spec paths(String.t()) :: [String.t()] | nil
  def paths(name), do: Map.get(@icons, resolve(name))

  @doc "The path data of the fallback icon."
  @spec fallback_paths() :: [String.t()]
  def fallback_paths, do: Map.fetch!(@icons, @fallback)

  @doc "All Lucide icon names."
  @spec names() :: [String.t()]
  def names, do: Map.keys(@icons)
end
