defmodule Feather.Sites do
  @moduledoc """
  Sites, their members, invitations, social media links and the main
  navigation.

  Changes the export shows that have no version of their own move the
  site's `updated_at` (`touch_site/1`), so
  `Feather.Publishing.undeployed_count/2` counts them once as not deployed
  yet: the settings, images, social media links and navigation here, and
  books and deleting or unpublishing a published record in
  `Feather.Books` and `Feather.Content`. Adding a page to the navigation or
  removing it counts only while the page is published, since the export
  leaves out the others.

  Authorisation: a user may access a site if they are a super admin or a
  member of it. Lookups for sites the user may not access behave as if the
  site did not exist (`Ecto.NoResultsError` / `nil`).
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts
  alias Feather.Accounts.{Scope, User}
  alias Feather.Content
  alias Feather.Content.Page
  alias Feather.Media.Cleanup
  alias Feather.Repo
  alias Feather.StaticSite.ImageVariants

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
  Lists the sites the scope's user may access, ordered by title (ignoring case).
  """
  @spec list_sites(Scope.t()) :: [Site.t()]
  def list_sites(%Scope{} = scope) do
    scope
    |> accessible_sites_query()
    |> order_by_title()
    |> Repo.all()
  end

  @doc """
  Lists the sites the scope's user is a member of, ordered by title
  (ignoring case). Unlike `list_sites/1` it leaves out the other sites of
  a super admin: connected apps reach only the member's sites (ADR 0031).
  """
  @spec list_member_sites(Scope.t()) :: [Site.t()]
  def list_member_sites(%Scope{user: %User{id: user_id}}) do
    user_id
    |> member_sites_query()
    |> order_by_title()
    |> Repo.all()
  end

  @doc """
  Gets a site the scope's user is a member of by its domain, normalized
  like the site form does, or nil. Super admin rights do not apply, as in
  `list_member_sites/1`.
  """
  @spec get_member_site_by_domain(Scope.t(), String.t()) :: Site.t() | nil
  def get_member_site_by_domain(%Scope{user: %User{id: user_id}}, domain)
      when is_binary(domain) do
    user_id
    |> member_sites_query()
    |> where([s], s.domain == ^Site.normalize_domain(domain))
    |> Repo.one()
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

  defp accessible_sites_query(%Scope{user: %User{id: user_id}}), do: member_sites_query(user_id)
  defp accessible_sites_query(%Scope{}), do: where(Site, false)

  defp member_sites_query(user_id) do
    from s in Site,
      join: su in SiteUser,
      on: su.site_id == s.id and su.user_id == ^user_id
  end

  defp order_by_title(query), do: order_by(query, [s], asc: fragment("? COLLATE NOCASE", s.title))

  @doc """
  Creates a site for the scope's user.

  In one transaction: saves the site, adds the creator as a member and
  creates and publishes the homepage (title "Home", slug "/").
  """
  @spec create_site(Scope.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def create_site(%Scope{user: %User{} = user}, attrs) do
    Repo.transact(fn ->
      with {:ok, site} <- %Site{} |> Site.create_changeset(attrs) |> Repo.insert(),
           {:ok, _site_user} <- add_member(site, user),
           {:ok, _homepage} <- create_homepage(site) do
        {:ok, site}
      end
    end)
  end

  # Published right away, so that a new site deploys with an index page.
  defp create_homepage(site) do
    scope = Scope.for_site(site)

    with {:ok, homepage} <- Feather.Content.create_page(scope, %{title: "Home", slug: "/"}) do
      Feather.Content.publish(scope, homepage)
    end
  end

  @doc """
  Updates a site. A new theme brings the image variants in line with it
  (`Feather.StaticSite.ImageVariants.start_sync/1`).
  """
  @spec update_site(Scope.t(), Site.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def update_site(%Scope{} = scope, %Site{} = site, attrs) do
    true = can_access_site?(scope, site)

    with {:ok, updated} <- site |> Site.changeset(attrs) |> Repo.update() do
      if updated.theme != site.theme, do: ImageVariants.start_sync(updated)
      {:ok, updated}
    end
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

  ## archive.org keys

  @archive_org_key_types %{access_key: :string, secret_key: :string}

  @doc """
  The archive.org keys of the scope's site (`%{access_key: _, secret_key:
  _}`), which deploys use to ask archive.org to save the changed pages
  (ADR 0027), or nil. Raises `ArgumentError` when they do not decrypt.
  """
  @spec archive_org_keys(Scope.t()) :: %{access_key: String.t(), secret_key: String.t()} | nil
  def archive_org_keys(%Scope{site: %Site{id: site_id}}) do
    case Repo.one(from s in Site, where: s.id == ^site_id, select: s.archive_org_keys) do
      %{"access_key" => access_key, "secret_key" => secret_key} ->
        %{access_key: access_key, secret_key: secret_key}

      _none ->
        nil
    end
  end

  @doc "Returns true if the scope's site has archive.org keys, without decrypting them."
  @spec archive_org_keys?(Scope.t()) :: boolean()
  def archive_org_keys?(%Scope{site: %Site{id: site_id}}) do
    Repo.exists?(from s in Site, where: s.id == ^site_id and not is_nil(s.archive_org_keys))
  end

  @doc "A changeset for entering archive.org keys (`access_key`, `secret_key`)."
  @spec change_archive_org_keys(map()) :: Ecto.Changeset.t()
  def change_archive_org_keys(attrs \\ %{}) do
    {%{}, @archive_org_key_types}
    |> Ecto.Changeset.cast(attrs, Map.keys(@archive_org_key_types))
    |> Feather.Validations.trim_to_nil(:access_key)
    |> Feather.Validations.trim_to_nil(:secret_key)
    |> Ecto.Changeset.validate_required(Map.keys(@archive_org_key_types))
    |> Ecto.Changeset.validate_length(:access_key, max: 200)
    |> Ecto.Changeset.validate_length(:secret_key, max: 200)
  end

  @doc """
  Stores the archive.org keys of the scope's site, encrypted. They are not
  part of the export, so the site's `updated_at` stays.
  """
  @spec put_archive_org_keys(Scope.t(), map()) :: :ok | {:error, Ecto.Changeset.t()}
  def put_archive_org_keys(%Scope{} = scope, attrs) do
    changeset = change_archive_org_keys(attrs)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, keys} -> set_archive_org_keys(scope, keys)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Removes the archive.org keys of the scope's site."
  @spec delete_archive_org_keys(Scope.t()) :: :ok
  def delete_archive_org_keys(%Scope{} = scope), do: set_archive_org_keys(scope, nil)

  defp set_archive_org_keys(%Scope{site: %Site{id: site_id}}, keys) do
    Repo.update_all(from(s in Site, where: s.id == ^site_id), set: [archive_org_keys: keys])
    :ok
  end

  ## Mascots and portrait

  @doc "The mascot slots of a site: `:footer`, `:post_end` and `:projects`."
  @spec mascot_slots() :: [Site.mascot_slot()]
  def mascot_slots, do: Site.mascot_slots()

  @doc """
  Preloads the images of a site: its mascots (`footer_mascot_image`,
  `post_end_mascot_image`, `projects_mascot_image`) and its
  `portrait_image`.
  """
  @spec preload_images(Site.t()) :: Site.t()
  def preload_images(%Site{} = site), do: Repo.preload(site, Site.image_assocs())

  @doc """
  Makes an uploaded file the mascot of a slot of the scope's site. The
  image it replaces is deleted unless something else still uses it (see
  `Cleanup.delete_released/1`). Returns the site with its
  images preloaded, or `{:error, changeset}` if the file is not a valid
  image.
  """
  @spec put_mascot(Scope.t(), Site.mascot_slot(), Path.t(), String.t()) ::
          {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def put_mascot(%Scope{} = scope, slot, path, filename) do
    true = slot in Site.mascot_slots()
    put_image(scope, Site.mascot_field(slot), path, filename)
  end

  @doc """
  Empties a mascot slot of the scope's site and deletes its image unless
  something else still uses it. Returns the site with its images
  preloaded.
  """
  @spec remove_mascot(Scope.t(), Site.mascot_slot()) ::
          {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def remove_mascot(%Scope{} = scope, slot) do
    true = slot in Site.mascot_slots()
    remove_image(scope, Site.mascot_field(slot))
  end

  @doc """
  Makes an uploaded file the portrait of the scope's site, like
  `put_mascot/4`.
  """
  @spec put_portrait(Scope.t(), Path.t(), String.t()) ::
          {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def put_portrait(%Scope{} = scope, path, filename),
    do: put_image(scope, :portrait_image_id, path, filename)

  @doc "Removes the portrait of the scope's site, like `remove_mascot/2`."
  @spec remove_portrait(Scope.t()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def remove_portrait(%Scope{} = scope), do: remove_image(scope, :portrait_image_id)

  defp put_image(%Scope{site: %Site{} = site} = scope, field, path, filename) do
    true = can_access_site?(scope, site)

    variants = ImageVariants.for_site_field(site, field)

    with {:ok, image} <-
           Feather.Media.create_image_from_upload(scope, path, filename, %{}, variants: variants) do
      case set_image(site, field, image) do
        {:ok, site} ->
          {:ok, site}

        {:error, reason} ->
          Feather.Media.delete_image(image)
          {:error, reason}
      end
    end
  end

  defp remove_image(%Scope{site: %Site{} = site} = scope, field) do
    true = can_access_site?(scope, site)
    set_image(site, field, nil)
  end

  defp set_image(%Site{id: site_id}, field, image) do
    result =
      Repo.transact(fn ->
        site = Repo.get!(Site, site_id)
        previous_id = Map.fetch!(site, field)

        with {:ok, site} <-
               site |> Ecto.Changeset.change(%{field => image && image.id}) |> Repo.update() do
          previous = previous_id && Repo.get(Feather.Media.Image, previous_id)
          {:ok, {site, Cleanup.delete_released(List.wrap(previous))}}
        end
      end)

    with {:ok, {site, deleted}} <- result do
      Enum.each(deleted, &Feather.Media.delete_image_files/1)
      {:ok, preload_images(site)}
    end
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
  Gets a member (site user) of the scope's site by id, user preloaded, or nil.
  """
  @spec get_member(Scope.t(), Ecto.UUID.t()) :: SiteUser.t() | nil
  def get_member(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one(from su in SiteUser, where: su.id == ^id and su.site_id == ^site_id, preload: :user)
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
  Gets an invitation of the scope's site by id, or nil.
  """
  @spec get_invitation(Scope.t(), Ecto.UUID.t()) :: Invitation.t() | nil
  def get_invitation(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one(from i in Invitation, where: i.id == ^id and i.site_id == ^site_id)
  end

  @doc """
  Invites an email address to the scope's site.

  Inviting an address again that has a pending invitation updates the
  inviting user. Existing members cannot be invited. Does not send the
  email, see `deliver_invitation/2`.
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

  # updated_at is part of the token, so sending again renews it even without other changes.
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
        accept_pending_invitation(invitation)
    end
  end

  defp accept_pending_invitation(invitation) do
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
  Gets a social media link of the scope's site, or nil.
  """
  @spec get_social_media_link(Scope.t(), Ecto.UUID.t()) :: SocialMediaLink.t() | nil
  def get_social_media_link(%Scope{site: %Site{id: site_id}}, id) do
    Repo.one(from l in SocialMediaLink, where: l.id == ^id and l.site_id == ^site_id)
  end

  @doc "Creates a social media link for the scope's site."
  @spec create_social_media_link(Scope.t(), map()) ::
          {:ok, SocialMediaLink.t()} | {:error, Ecto.Changeset.t()}
  def create_social_media_link(%Scope{site: %Site{id: site_id}} = scope, attrs) do
    %SocialMediaLink{site_id: site_id}
    |> SocialMediaLink.changeset(attrs)
    |> Repo.insert()
    |> touch_site_on_success(scope)
  end

  @doc "Deletes a social media link."
  @spec delete_social_media_link(Scope.t(), SocialMediaLink.t()) :: {:ok, SocialMediaLink.t()}
  def delete_social_media_link(%Scope{site: %Site{id: site_id}} = scope, link) do
    %SocialMediaLink{site_id: ^site_id} = link

    link
    |> Repo.delete()
    |> touch_site_on_success(scope)
  end

  @doc "Returns a changeset for a social media link form."
  @spec change_social_media_link(SocialMediaLink.t(), map()) :: Ecto.Changeset.t()
  def change_social_media_link(%SocialMediaLink{} = link, attrs \\ %{}) do
    SocialMediaLink.changeset(link, attrs)
  end

  ## Navigation

  @doc """
  Lists the navigation items of the scope's site by position, pages (with
  their published version) preloaded.
  """
  @spec list_navigation_items(Scope.t()) :: [NavigationItem.t()]
  def list_navigation_items(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from n in NavigationItem,
        where: n.site_id == ^site_id,
        order_by: [asc: n.position],
        preload: [page: :published_version]
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
  def add_to_navigation(%Scope{site: %Site{id: site_id}} = scope, %Page{site_id: site_id} = page) do
    Repo.transact(fn ->
      case Repo.get_by(NavigationItem, site_id: site_id, page_id: page.id) do
        %NavigationItem{} = item ->
          {:ok, item}

        nil ->
          append_to_navigation(scope, page)
      end
    end)
  end

  defp append_to_navigation(%Scope{site: %Site{id: site_id}} = scope, page) do
    max =
      Repo.one(from n in NavigationItem, where: n.site_id == ^site_id, select: max(n.position))

    with {:ok, item} <-
           Repo.insert(%NavigationItem{
             site_id: site_id,
             page_id: page.id,
             position: (max || 0) + 1
           }) do
      if Content.stored_published?(page), do: touch_site(scope)
      {:ok, item}
    end
  end

  @doc """
  Removes the page from the navigation of the scope's site and closes the
  gap in the positions.
  """
  @spec remove_from_navigation(Scope.t(), Page.t()) :: :ok
  def remove_from_navigation(
        %Scope{site: %Site{id: site_id}} = scope,
        %Page{site_id: site_id} = page
      ) do
    {:ok, :ok} =
      Repo.transact(fn ->
        {deleted, _} =
          Repo.delete_all(
            from n in NavigationItem, where: n.site_id == ^site_id and n.page_id == ^page.id
          )

        renumber_navigation(site_id)
        if deleted > 0 and Content.stored_published?(page), do: touch_site(scope)
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

  defp move_navigation_item(
         %Scope{site: %Site{id: site_id}} = scope,
         %NavigationItem{} = item,
         offset
       ) do
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

        moves? = index && target >= 0 && target < length(ids)

        ids =
          if moves? do
            ids
            |> List.replace_at(index, Enum.at(ids, target))
            |> List.replace_at(target, item.id)
          else
            ids
          end

        write_positions(ids)
        if moves?, do: touch_site(scope)
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

  defp touch_site_on_success({:ok, _record} = result, scope) do
    touch_site(scope)
    result
  end

  defp touch_site_on_success(error, _scope), do: error

  @doc """
  Moves the `updated_at` of the scope's site, for a change the export shows
  that has no version of its own (see the module doc).
  """
  @spec touch_site(Scope.t()) :: :ok
  def touch_site(%Scope{site: %Site{id: site_id}}) do
    Repo.update_all(from(s in Site, where: s.id == ^site_id),
      set: [updated_at: DateTime.utc_now()]
    )

    :ok
  end

  defp write_positions(ids) do
    ids
    |> Enum.with_index(1)
    |> Enum.each(fn {id, position} ->
      Repo.update_all(from(n in NavigationItem, where: n.id == ^id), set: [position: position])
    end)
  end
end
