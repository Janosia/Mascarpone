defmodule Mascarpone.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Mascarpone.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Mascarpone.Accounts.CheeseBytes

  defstruct cheese_bytes: nil

  @doc """
  Creates a scope for the given cheese_bytes.

  Returns nil if no cheese_bytes is given.
  """
  def for_cheese_bytes(%CheeseBytes{} = cheese_bytes) do
    %__MODULE__{cheese_bytes: cheese_bytes}
  end

  def for_cheese_bytes(nil), do: nil
end
