defmodule Feather.Sites.SocialMediaService do
  @moduledoc """
  The social media services a site can link to, with their brand icons.

  The SVG icons live in `priv/icons/<icon>.svg`.
  """

  @enforce_keys [:key, :name, :icon, :url_placeholder]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          key: atom(),
          name: String.t(),
          icon: String.t(),
          url_placeholder: String.t()
        }

  @services [
    {:facebook, "Facebook", "https://www.facebook.com/john.doe"},
    {:github, "GitHub", "https://github.com/johndoe"},
    {:gitlab, "GitLab", "https://gitlab.com/johndoe"},
    {:instagram, "Instagram", "https://www.instagram.com/johndoe"},
    {:linkedin, "LinkedIn", "https://www.linkedin.com/in/johndoe"},
    {:mastodon, "Mastodon", "https://mastodon.social/@johndoe"},
    {:reddit, "Reddit", "https://www.reddit.com/user/johndoe"},
    {:rss, "RSS", "https://example.com/feed.xml"},
    {:vimeo, "Vimeo", "https://vimeo.com/johndoe"},
    {:whatsapp, "WhatsApp", "https://wa.me/1234567890"},
    {:youtube, "YouTube", "https://www.youtube.com/channel/UCjohndoe"}
  ]

  @icons Enum.map(@services, fn {key, _name, _placeholder} -> Atom.to_string(key) end)

  for icon <- @icons do
    @external_resource Path.join([__DIR__, "../../../priv/icons", "#{icon}.svg"])
  end

  @svgs Map.new(@icons, fn icon ->
          {icon, File.read!(Path.join([__DIR__, "../../../priv/icons", "#{icon}.svg"]))}
        end)

  @doc "All services, in display order."
  @spec all() :: [t()]
  def all do
    Enum.map(@services, fn {key, name, placeholder} ->
      %__MODULE__{key: key, name: name, icon: Atom.to_string(key), url_placeholder: placeholder}
    end)
  end

  @doc "All valid icon names."
  @spec icons() :: [String.t()]
  def icons, do: @icons

  @doc "Finds a service by its icon name."
  @spec find(String.t()) :: t() | nil
  def find(icon), do: Enum.find(all(), &(&1.icon == icon))

  @doc "The raw SVG markup of an icon, or nil for an unknown icon."
  @spec svg(String.t()) :: String.t() | nil
  def svg(icon), do: Map.get(@svgs, icon)
end
