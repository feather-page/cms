defmodule Feather.OAuth.AuthorizationRequest do
  @moduledoc """
  A client's checked request to connect, as the consent page shows it and
  `Feather.OAuth.approve/2` turns it into an authorization code. `state` is
  the client's own value, handed back unchanged.
  """

  defstruct [:client_id, :client_name, :redirect_uri, :code_challenge, :state]

  @type t :: %__MODULE__{
          client_id: String.t(),
          client_name: String.t(),
          redirect_uri: String.t(),
          code_challenge: String.t(),
          state: String.t() | nil
        }
end
