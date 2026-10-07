defmodule Feather.Sites do
  @moduledoc """
  Sites, their members, invitations, social media links and the main
  navigation.

  Authorisation: a user may access a site if they are a super admin or a
  member of it. Lookups for sites the user may not access behave as if the
  site did not exist (`Ecto.NoResultsError` / `nil`).
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Accounts
  alias Feather.Accounts.{Scope, User}
  alias Feather.Content.Page

  alias Feather.Sites.{
    Invitation,
    InvitationNotifier,
    NavigationItem,
    Site,
    SiteUser,
    SocialMediaLink
  }

  @invitation_salt "site invitation"
  @invitation_max_age 7 * 24 * 60 * 60

  ## Sites

  @doc """
  Lists the sites the scope's user may access, ordered by title.
  """
  @spec list_sites(Scope.t()) :: [Site.t()]
  def list_sites(%Scope{} = scope) do
    scope
    |> accessible_sites_query()
    |> order_by([s], asc: s.title)
    |> Repo.all()
  end

  @doc """
  Gets a site by public id.

  Raises `Ecto.NoResultsError` if the site does not exist or the user may
  not access it.
  """
  @spec get_site!(Scope.t(), String.t()) :: Site.t()
  def get_site!(%Scope{} = scope, public_id) do
    scope
    |> accessible_sites_query()
    |> where([s], s.public_id == ^public_id)
    |> Repo.one!()
  end

  @doc """
  Gets a site by public id, or nil if it does not exist or the user may not
  access it.
  """
  @spec get_site(Scope.t(), String.t()) :: Site.t() | nil
  def get_site(%Scope{} = scope, public_id) do
    scope
    |> accessible_sites_query()
    |> where([s], s.public_id == ^public_id)
    |> Repo.one()
  end

  @doc """
  Returns true if the user (or the scope's user) may access the site.
  """
  @spec can_access_site?(Scope.t() | User.t() | nil, Site.t()) :: boolean()
  def can_access_site?(%Scope{user: user}, %Site{} = site), do: can_access_site?(user, site)
  def can_access_site?(%User{super_admin: true}, %Site{}), do: true

  def can_access_site?(%User{} = user, %Site{} = site), do: member?(site, user)

  def can_access_site?(nil, %Site{}), do: false

  defp accessible_sites_query(%Scope{user: %User{super_admin: true}}), do: Site

  defp accessible_sites_query(%Scope{user: %User{id: user_id}}) do
    from s in Site,
      join: su in SiteUser,
      on: su.site_id == s.id and su.user_id == ^user_id
  end

  defp accessible_sites_query(%Scope{}), do: where(Site, false)

  @doc """
  Creates a site for the scope's user.

  Like Rails' `Sites::CreateSite`, in one transaction: saves the site, adds
  the creator as a member, creates the homepage (title "Home", slug "/")
  and the internal staging deployment target.
  """
  @spec create_site(Scope.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def create_site(%Scope{user: %User{} = user}, attrs) do
    Repo.transact(fn ->
      with {:ok, site} <- %Site{} |> Site.create_changeset(attrs) |> Repo.insert(),
           {:ok, _site_user} <- add_member(site, user),
           {:ok, _homepage} <-
             Feather.Content.create_page(Scope.for_site(site), %{title: "Home", slug: "/"}),
           {:ok, _target} <- Feather.Publishing.create_staging_target(site) do
        {:ok, site}
      end
    end)
  end

  @doc """
  Updates a site.
  """
  @spec update_site(Scope.t(), Site.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def update_site(%Scope{} = scope, %Site{} = site, attrs) do
    true = can_access_site?(scope, site)

    site
    |> Site.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a site with all its content. Image files are removed as well.
  """
  @spec delete_site(Scope.t(), Site.t()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def delete_site(%Scope{} = scope, %Site{} = site) do
    true = can_access_site?(scope, site)

    images = Repo.all(from i in Feather.Media.Image, where: i.site_id == ^site.id)

    with {:ok, site} <- Repo.delete(site) do
      Enum.each(images, &Feather.Media.delete_image_files/1)
      {:ok, site}
    end
  end

  @doc """
  Returns a changeset for tracking site changes.
  """
  @spec change_site(Site.t(), map()) :: Ecto.Changeset.t()
  def change_site(%Site{} = site, attrs \\ %{}) do
    Site.changeset(site, attrs)
  end

  ## Members

  @doc """
  Lists the members of the scope's site, with users preloaded, by email.
  """
  @spec list_members(Scope.t()) :: [SiteUser.t()]
  def list_members(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from su in SiteUser,
        join: u in assoc(su, :user),
        where: su.site_id == ^site_id,
        order_by: [asc: u.email],
        preload: [user: u]
    )
  end

  @doc """
  Gets a member (site user) of the scope's site by id, user preloaded.
  Raises `Ecto.NoResultsError` if not found.
  """
  @spec get_member!(Scope.t(), Ecto.UUID.t()) :: SiteUser.t()
  def get_member!(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one!(from su in SiteUser, where: su.id == ^id and su.site_id == ^site_id, preload: :user)
  end

  @doc """
  Returns true if the user is a member of the site.
  """
  @spec member?(Site.t(), User.t()) :: boolean()
  def member?(%Site{id: site_id}, %User{id: user_id}) do
    Repo.exists?(from su in SiteUser, where: su.site_id == ^site_id and su.user_id == ^user_id)
  end

  @doc """
  Adds the user as a member of the site. Adding an existing member is a no-op.
  """
  @spec add_member(Site.t(), User.t()) :: {:ok, SiteUser.t()} | {:error, Ecto.Changeset.t()}
  def add_member(%Site{} = site, %User{} = user) do
    case Repo.get_by(SiteUser, site_id: site.id, user_id: user.id) do
      %SiteUser{} = site_user ->
        {:ok, site_user}

      nil ->
        %SiteUser{site_id: site.id, user_id: user.id}
        |> SiteUser.changeset(%{})
        |> Repo.insert()
    end
  end

  @doc """
  Removes a member from the scope's site. Users cannot remove themselves.
  """
  @spec remove_member(Scope.t(), SiteUser.t()) ::
          {:ok, SiteUser.t()} | {:error, :cannot_remove_self}
  def remove_member(
        %Scope{user: user, site: %Site{id: site_id}},
        %SiteUser{site_id: site_id} = su
      ) do
    if user && su.user_id == user.id do
      {:error, :cannot_remove_self}
    else
      Repo.delete(su)
    end
  end

  ## Invitations

  @doc """
  Lists the pending invitations of the scope's site.
  """
  @spec list_pending_invitations(Scope.t()) :: [Invitation.t()]
  def list_pending_invitations(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from i in Invitation,
        where: i.site_id == ^site_id and is_nil(i.accepted_at),
        order_by: [asc: i.email]
    )
  end

  @doc """
  Gets an invitation of the scope's site by id. Raises if not found.
  """
  @spec get_invitation!(Scope.t(), Ecto.UUID.t()) :: Invitation.t()
  def get_invitation!(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one!(from i in Invitation, where: i.id == ^id and i.site_id == ^site_id)
  end

  @doc """
  Invites an email address to the scope's site.

  Inviting an address again that has a pending invitation updates the
  inviting user, like Rails did. Existing members cannot be invited.
  Does not send the email, see `deliver_invitation/2`.
  """
  @spec create_invitation(Scope.t(), map()) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
  def create_invitation(%Scope{user: %User{} = inviter, site: %Site{} = site}, attrs) do
    email =
      %Invitation{}
      |> Ecto.Changeset.cast(attrs, [:email])
      |> Ecto.Changeset.get_field(:email)

    existing =
      is_binary(email) &&
        Repo.get_by(Invitation,
          site_id: site.id,
          email: email |> String.trim() |> String.downcase()
        )

    (existing || %Invitation{site_id: site.id})
    |> Invitation.changeset(attrs)
    |> Ecto.Changeset.put_change(:inviting_user_id, inviter.id)
    |> Ecto.Changeset.put_change(:accepted_at, nil)
    |> renew_token()
    |> validate_not_member(site)
    |> Repo.insert_or_update()
  end

  defp validate_not_member(changeset, site) do
    email = Ecto.Changeset.get_field(changeset, :email)

    member? =
      is_binary(email) &&
        Repo.exists?(
          from su in SiteUser,
            join: u in assoc(su, :user),
            where: su.site_id == ^site.id and u.email == ^email
        )

    if member? do
      Ecto.Changeset.add_error(changeset, :email, "is already a member of this site")
    else
      changeset
    end
  end

  @doc """
  Returns a changeset for an invitation form.
  """
  @spec change_invitation(Invitation.t(), map()) :: Ecto.Changeset.t()
  def change_invitation(%Invitation{} = invitation, attrs \\ %{}) do
    Invitation.changeset(invitation, attrs)
  end

  @doc """
  Sends the invitation email. `accept_url_fun` receives the token and
  returns the acceptance URL.
  """
  @spec deliver_invitation(Invitation.t(), (String.t() -> String.t())) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_invitation(%Invitation{} = invitation, accept_url_fun)
      when is_function(accept_url_fun, 1) do
    invitation = Repo.preload(invitation, [:site, :inviting_user])

    InvitationNotifier.deliver_invitation(
      invitation,
      accept_url_fun.(invitation_token(invitation))
    )
  end

  @doc """
  Sends a pending invitation again, with the scope's user as inviter.
  """
  @spec resend_invitation(Scope.t(), Invitation.t(), (String.t() -> String.t())) ::
          {:ok, Invitation.t()} | {:error, :already_accepted}
  def resend_invitation(
        %Scope{user: %User{} = user, site: %Site{id: site_id}},
        invitation,
        url_fun
      ) do
    %Invitation{site_id: ^site_id} = invitation

    if Invitation.accepted?(invitation) do
      {:error, :already_accepted}
    else
      invitation =
        invitation
        |> Ecto.Changeset.change(inviting_user_id: user.id)
        |> renew_token()
        |> Repo.update!()

      {:ok, _email} = deliver_invitation(invitation, url_fun)
      {:ok, invitation}
    end
  end

  @doc """
  Deletes an invitation of the scope's site.
  """
  @spec delete_invitation(Scope.t(), Invitation.t()) :: {:ok, Invitation.t()}
  def delete_invitation(%Scope{site: %Site{id: site_id}}, %Invitation{site_id: site_id} = inv) do
    Repo.delete(inv)
  end

  @doc """
  The token for the acceptance link: a `Phoenix.Token` with the invitation
  id and its `updated_at`, valid for 7 days. Inviting the address again
  and resending update the invitation, so links sent before stop working.
  """
  @spec invitation_token(Invitation.t()) :: String.t()
  def invitation_token(%Invitation{id: id, updated_at: updated_at}) do
    Phoenix.Token.sign(FeatherWeb.Endpoint, @invitation_salt, {id, token_version(updated_at)})
  end

  defp token_version(%DateTime{} = updated_at), do: DateTime.to_unix(updated_at, :microsecond)

  # An existing invitation sent again gets a new updated_at, which is part
  # of its token, also when nothing else changes.
  defp renew_token(%Ecto.Changeset{data: %Invitation{id: nil}} = changeset), do: changeset

  defp renew_token(changeset),
    do: Ecto.Changeset.force_change(changeset, :updated_at, DateTime.utc_now())

  @doc """
  Finds the pending invitation for an acceptance token.
  """
  @spec get_invitation_by_token(String.t()) ::
          {:ok, Invitation.t()} | {:error, :invalid | :expired | :already_accepted}
  def get_invitation_by_token(token) when is_binary(token) do
    with {:ok, {id, version}} <-
           Phoenix.Token.verify(FeatherWeb.Endpoint, @invitation_salt, token,
             max_age: @invitation_max_age
           ),
         %Invitation{} = invitation <- Repo.get(Invitation, id) do
      cond do
        Invitation.accepted?(invitation) -> {:error, :already_accepted}
        token_version(invitation.updated_at) != version -> {:error, :invalid}
        true -> {:ok, Repo.preload(invitation, :site)}
      end
    else
      {:error, :expired} -> {:error, :expired}
      _ -> {:error, :invalid}
    end
  end

  @doc """
  Accepts an invitation: finds or creates the user for the invited email,
  makes them a member, marks the invitation accepted and notifies the
  inviting user.

  `current_user` is the logged-in user or nil. A logged-in user can only
  accept invitations sent to their own email address.
  """
  @spec accept_invitation(Invitation.t(), User.t() | nil) ::
          {:ok, %{user: User.t(), site: Site.t(), invitation: Invitation.t()}}
          | {:error, :already_accepted | :email_mismatch | Ecto.Changeset.t()}
  def accept_invitation(%Invitation{} = invitation, current_user) do
    cond do
      Invitation.accepted?(invitation) ->
        {:error, :already_accepted}

      current_user && current_user.email != invitation.email ->
        {:error, :email_mismatch}

      true ->
        invitation = Repo.preload(invitation, [:site, :inviting_user])

        result =
          Repo.transact(fn ->
            with {:ok, user} <- Accounts.get_or_create_user_by_email(invitation.email),
                 {:ok, _site_user} <- add_member(invitation.site, user),
                 {:ok, invitation} <-
                   invitation
                   |> Ecto.Changeset.change(accepted_at: DateTime.utc_now())
                   |> Repo.update() do
              {:ok, %{user: user, site: invitation.site, invitation: invitation}}
            end
          end)

        with {:ok, %{invitation: invitation}} <- result do
          InvitationNotifier.deliver_invitation_accepted(invitation)
        end

        result
    end
  end

  ## Social media links

  @doc """
  Lists the social media links of the scope's site in creation order.
  """
  @spec list_social_media_links(Scope.t()) :: [SocialMediaLink.t()]
  def list_social_media_links(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from l in SocialMediaLink, where: l.site_id == ^site_id, order_by: [asc: l.inserted_at]
    )
  end

  @doc """
  Gets a social media link of the scope's site. Raises if not found.
  """
  @spec get_social_media_link!(Scope.t(), Ecto.UUID.t()) :: SocialMediaLink.t()
  def get_social_media_link!(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one!(from l in SocialMediaLink, where: l.id == ^id and l.site_id == ^site_id)
  end

  @doc "Creates a social media link for the scope's site."
  @spec create_social_media_link(Scope.t(), map()) ::
          {:ok, SocialMediaLink.t()} | {:error, Ecto.Changeset.t()}
  def create_social_media_link(%Scope{site: %Site{id: site_id}}, attrs) do
    %SocialMediaLink{site_id: site_id}
    |> SocialMediaLink.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a social media link."
  @spec update_social_media_link(Scope.t(), SocialMediaLink.t(), map()) ::
          {:ok, SocialMediaLink.t()} | {:error, Ecto.Changeset.t()}
  def update_social_media_link(%Scope{site: %Site{id: site_id}}, link, attrs) do
    %SocialMediaLink{site_id: ^site_id} = link

    link
    |> SocialMediaLink.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a social media link."
  @spec delete_social_media_link(Scope.t(), SocialMediaLink.t()) :: {:ok, SocialMediaLink.t()}
  def delete_social_media_link(%Scope{site: %Site{id: site_id}}, link) do
    %SocialMediaLink{site_id: ^site_id} = link
    Repo.delete(link)
  end

  @doc "Returns a changeset for a social media link form."
  @spec change_social_media_link(SocialMediaLink.t(), map()) :: Ecto.Changeset.t()
  def change_social_media_link(%SocialMediaLink{} = link, attrs \\ %{}) do
    SocialMediaLink.changeset(link, attrs)
  end

  ## Navigation

  @doc """
  Lists the navigation items of the scope's site by position, pages preloaded.
  """
  @spec list_navigation_items(Scope.t()) :: [NavigationItem.t()]
  def list_navigation_items(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from n in NavigationItem,
        where: n.site_id == ^site_id,
        order_by: [asc: n.position],
        preload: :page
    )
  end

  @doc """
  Returns true if the page is in its site's navigation.
  """
  @spec in_navigation?(Page.t()) :: boolean()
  def in_navigation?(%Page{id: nil}), do: false

  def in_navigation?(%Page{id: page_id}) do
    Repo.exists?(from n in NavigationItem, where: n.page_id == ^page_id)
  end

  @doc """
  Appends the page to the navigation of the scope's site. Adding a page
  that is already in the navigation returns the existing item.
  """
  @spec add_to_navigation(Scope.t(), Page.t()) ::
          {:ok, NavigationItem.t()} | {:error, Ecto.Changeset.t()}
  def add_to_navigation(%Scope{site: %Site{id: site_id}}, %Page{site_id: site_id} = page) do
    Repo.transact(fn ->
      case Repo.get_by(NavigationItem, site_id: site_id, page_id: page.id) do
        %NavigationItem{} = item ->
          {:ok, item}

        nil ->
          max =
            Repo.one(
              from n in NavigationItem, where: n.site_id == ^site_id, select: max(n.position)
            )

          Repo.insert(%NavigationItem{
            site_id: site_id,
            page_id: page.id,
            position: (max || 0) + 1
          })
      end
    end)
  end

  @doc """
  Removes the page from the navigation of the scope's site and closes the
  gap in the positions.
  """
  @spec remove_from_navigation(Scope.t(), Page.t()) :: :ok
  def remove_from_navigation(%Scope{site: %Site{id: site_id}}, %Page{site_id: site_id} = page) do
    {:ok, :ok} =
      Repo.transact(fn ->
        Repo.delete_all(
          from n in NavigationItem, where: n.site_id == ^site_id and n.page_id == ^page.id
        )

        renumber_navigation(site_id)
        {:ok, :ok}
      end)

    :ok
  end

  @doc """
  Moves a navigation item one position up (towards the start). The first
  item stays where it is.
  """
  @spec move_navigation_item_up(Scope.t(), NavigationItem.t()) :: :ok
  def move_navigation_item_up(%Scope{} = scope, %NavigationItem{} = item),
    do: move_navigation_item(scope, item, -1)

  @doc """
  Moves a navigation item one position down (towards the end). The last
  item stays where it is.
  """
  @spec move_navigation_item_down(Scope.t(), NavigationItem.t()) :: :ok
  def move_navigation_item_down(%Scope{} = scope, %NavigationItem{} = item),
    do: move_navigation_item(scope, item, 1)

  defp move_navigation_item(%Scope{site: %Site{id: site_id}}, %NavigationItem{} = item, offset) do
    %NavigationItem{site_id: ^site_id} = item

    {:ok, :ok} =
      Repo.transact(fn ->
        ids =
          Repo.all(
            from n in NavigationItem,
              where: n.site_id == ^site_id,
              order_by: [asc: n.position, asc: n.inserted_at],
              select: n.id
          )

        index = Enum.find_index(ids, &(&1 == item.id))
        target = index && index + offset

        ids =
          if index && target >= 0 && target < length(ids) do
            ids
            |> List.replace_at(index, Enum.at(ids, target))
            |> List.replace_at(target, item.id)
          else
            ids
          end

        write_positions(ids)
        {:ok, :ok}
      end)

    :ok
  end

  defp renumber_navigation(site_id) do
    from(n in NavigationItem,
      where: n.site_id == ^site_id,
      order_by: [asc: n.position, asc: n.inserted_at],
      select: n.id
    )
    |> Repo.all()
    |> write_positions()
  end

  defp write_positions(ids) do
    ids
    |> Enum.with_index(1)
    |> Enum.each(fn {id, position} ->
      Repo.update_all(from(n in NavigationItem, where: n.id == ^id), set: [position: position])
    end)
  end
end
