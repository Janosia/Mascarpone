defmodule Mascarpone.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mascarpone.Accounts` context.
  """

  import Ecto.Query

  alias Mascarpone.Accounts
  alias Mascarpone.Accounts.Scope

  def unique_cheese_bytes_email, do: "cheese_bytes#{System.unique_integer()}@example.com"
  def valid_cheese_bytes_password, do: "hello world!"

  def valid_cheese_bytes_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_cheese_bytes_email()
    })
  end

  def unconfirmed_cheese_bytes_fixture(attrs \\ %{}) do
    {:ok, cheese_bytes} =
      attrs
      |> valid_cheese_bytes_attributes()
      |> Accounts.register_cheese_bytes()

    cheese_bytes
  end

  def cheese_bytes_fixture(attrs \\ %{}) do
    cheese_bytes = unconfirmed_cheese_bytes_fixture(attrs)

    token =
      extract_cheese_bytes_token(fn url ->
        Accounts.deliver_login_instructions(cheese_bytes, url)
      end)

    {:ok, cheese_bytes, _expired_tokens} = Accounts.login_cheese_bytes_by_magic_link(token)

    cheese_bytes
  end

  def cheese_bytes_scope_fixture do
    cheese_bytes = cheese_bytes_fixture()
    cheese_bytes_scope_fixture(cheese_bytes)
  end

  def cheese_bytes_scope_fixture(cheese_bytes) do
    Scope.for_cheese_bytes(cheese_bytes)
  end

  def set_password(cheese_bytes) do
    {:ok, cheese_bytes, _expired_tokens} =
      Accounts.update_cheese_bytes_password(cheese_bytes, %{password: valid_cheese_bytes_password()})

    cheese_bytes
  end

  def extract_cheese_bytes_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Mascarpone.Repo.update_all(
      from(t in Accounts.CheeseBytesToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_cheese_bytes_magic_link_token(cheese_bytes) do
    {encoded_token, cheese_bytes_token} = Accounts.CheeseBytesToken.build_email_token(cheese_bytes, "login")
    Mascarpone.Repo.insert!(cheese_bytes_token)
    {encoded_token, cheese_bytes_token.token}
  end

  def offset_cheese_bytes_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Mascarpone.Repo.update_all(
      from(ut in Accounts.CheeseBytesToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
