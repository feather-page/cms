# Seeds for development: a super admin and a demo site.
#
#     mix run priv/repo/seeds.exs
#
# Log in as admin@example.com; the magic link shows up in /dev/mailbox.
# The script can run repeatedly.

alias Feather.{Accounts, Content, Repo, Sites}
alias Feather.Accounts.Scope

{:ok, admin} = Accounts.get_or_create_user_by_email("admin@example.com")
{:ok, admin} = Accounts.set_super_admin(admin, true)

scope = Scope.for_user(admin)

site =
  case Repo.get_by(Sites.Site, domain: "demo.example.com") do
    nil ->
      {:ok, site} =
        Sites.create_site(scope, %{
          title: "Demo Site",
          domain: "demo.example.com",
          language_code: "en",
          emoji: "🪶"
        })

      site_scope = Scope.put_site(scope, site)

      {:ok, post} =
        Content.create_post(site_scope, %{
          title: "Hello World",
          slug: "/hello-world",
          tags: "welcome, demo",
          content: [
            %{"type" => "paragraph", "text" => "This is the <b>first post</b> of the demo site."},
            %{"type" => "header", "level" => 2, "text" => "What next?"},
            %{
              "type" => "list",
              "style" => "ul",
              "items" => [
                %{"content" => "Write a post", "items" => []},
                %{"content" => "Publish to staging", "items" => []}
              ]
            }
          ]
        })

      {:ok, page} =
        Content.create_page(site_scope, %{
          title: "About",
          slug: "/about",
          add_to_navigation: true,
          content: [%{"type" => "paragraph", "text" => "About this site."}]
        })

      {:ok, _post} = Content.publish(site_scope, post)
      {:ok, _page} = Content.publish(site_scope, page)

      site

    site ->
      site
  end

IO.puts("Seeded #{admin.email} (super admin) and #{site.title} (#{site.public_id}).")
