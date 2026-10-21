defmodule Feather.RedirectsFixtures do
  @moduledoc """
  Test helpers for redirects. All take a scope with a site.
  """

  def redirect_fixture(scope, attrs) do
    {:ok, redirect} = Feather.Redirects.create_redirect(scope, Map.new(attrs))
    redirect
  end
end
