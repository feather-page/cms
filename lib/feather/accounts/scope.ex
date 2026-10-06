defmodule Feather.Accounts.Scope do
  @moduledoc """
  The scope of a caller, passed as the first argument to context functions.

  A scope carries the current `user` and, once a site has been chosen, the
  current `site`. Content functions (`Feather.Content`, `Feather.Books`,
  `Feather.Media`, `Feather.Publishing`, the site-level parts of
  `Feather.Sites`) work on `scope.site` and trust it: only put a site into a
  scope that came out of an authorised lookup such as
  `Feather.Sites.get_site!/2`, or use `for_site/1` in trusted internal code
  (export, import, background work).

  Authorisation rule (ported from the Rails policies): a user may access a
  site if they are a super admin or a member of the site (`site_users`).
  """

  alias Feather.Accounts.User
  alias Feather.Sites.Site

  defstruct user: nil, site: nil

  @type t :: %__MODULE__{user: User.t() | nil, site: Site.t() | nil}

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Returns the scope with the given site as the current site.

  The caller is responsible for having checked access, typically by loading
  the site with `Feather.Sites.get_site!/2`.
  """
  def put_site(%__MODULE__{} = scope, %Site{} = site) do
    %{scope | site: site}
  end

  @doc """
  A scope without a user for trusted internal code working on one site.
  """
  def for_site(%Site{} = site) do
    %__MODULE__{site: site}
  end

  @doc """
  Returns true if the scope's user is a super admin.
  """
  def super_admin?(%__MODULE__{user: %User{super_admin: true}}), do: true
  def super_admin?(_scope), do: false
end
