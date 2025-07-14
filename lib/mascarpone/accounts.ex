defmodule Mascarpone.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Mascarpone.Repo

  alias Mascarpone.Accounts.{CheeseBytes, CheeseBytesToken, CheeseBytesNotifier}

  ## Database getters

  @doc """
  Gets a cheese_bytes by email.

  ## Examples

      iex> get_cheese_bytes_by_email("foo@example.com")
      %CheeseBytes{}

      iex> get_cheese_bytes_by_email("unknown@example.com")
      nil

  """
  def get_cheese_bytes_by_email(email) when is_binary(email) do
    Repo.get_by(CheeseBytes, email: email)
  end

  @doc """
  Gets a cheese_bytes by email and password.

  ## Examples

      iex> get_cheese_bytes_by_email_and_password("foo@example.com", "correct_password")
      %CheeseBytes{}

      iex> get_cheese_bytes_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_cheese_bytes_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    cheese_bytes = Repo.get_by(CheeseBytes, email: email)
    if CheeseBytes.valid_password?(cheese_bytes, password), do: cheese_bytes
  end

  @doc """
  Gets a single cheese_bytes.

  Raises `Ecto.NoResultsError` if the CheeseBytes does not exist.

  ## Examples

      iex> get_cheese_bytes!(123)
      %CheeseBytes{}

      iex> get_cheese_bytes!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cheese_bytes!(id), do: Repo.get!(CheeseBytes, id)

  ## Cheese bytes registration

  @doc """
  Registers a cheese_bytes.

  ## Examples

      iex> register_cheese_bytes(%{field: value})
      {:ok, %CheeseBytes{}}

      iex> register_cheese_bytes(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_cheese_bytes(attrs) do
    %CheeseBytes{}
    |> CheeseBytes.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the cheese_bytes is in sudo mode.

  The cheese_bytes is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(cheese_bytes, minutes \\ -20)

  def sudo_mode?(%CheeseBytes{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_cheese_bytes, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the cheese_bytes email.

  See `Mascarpone.Accounts.CheeseBytes.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_cheese_bytes_email(cheese_bytes)
      %Ecto.Changeset{data: %CheeseBytes{}}

  """
  def change_cheese_bytes_email(cheese_bytes, attrs \\ %{}, opts \\ []) do
    CheeseBytes.email_changeset(cheese_bytes, attrs, opts)
  end

  @doc """
  Updates the cheese_bytes email using the given token.

  If the token matches, the cheese_bytes email is updated and the token is deleted.
  """
  def update_cheese_bytes_email(cheese_bytes, token) do
    context = "change:#{cheese_bytes.email}"

    with {:ok, query} <- CheeseBytesToken.verify_change_email_token_query(token, context),
         %CheeseBytesToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(cheese_bytes_email_multi(cheese_bytes, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp cheese_bytes_email_multi(cheese_bytes, email, context) do
    changeset = CheeseBytes.email_changeset(cheese_bytes, %{email: email})

    Ecto.Multi.new()
    |> Ecto.Multi.update(:cheese_bytes, changeset)
    |> Ecto.Multi.delete_all(:tokens, CheeseBytesToken.by_cheese_bytes_and_contexts_query(cheese_bytes, [context]))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the cheese_bytes password.

  See `Mascarpone.Accounts.CheeseBytes.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_cheese_bytes_password(cheese_bytes)
      %Ecto.Changeset{data: %CheeseBytes{}}

  """
  def change_cheese_bytes_password(cheese_bytes, attrs \\ %{}, opts \\ []) do
    CheeseBytes.password_changeset(cheese_bytes, attrs, opts)
  end

  @doc """
  Updates the cheese_bytes password.

  Returns the updated cheese_bytes, as well as a list of expired tokens.

  ## Examples

      iex> update_cheese_bytes_password(cheese_bytes, %{password: ...})
      {:ok, %CheeseBytes{}, [...]}

      iex> update_cheese_bytes_password(cheese_bytes, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_cheese_bytes_password(cheese_bytes, attrs) do
    cheese_bytes
    |> CheeseBytes.password_changeset(attrs)
    |> update_cheese_bytes_and_delete_all_tokens()
    |> case do
      {:ok, cheese_bytes, expired_tokens} -> {:ok, cheese_bytes, expired_tokens}
      {:error, :cheese_bytes, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_cheese_bytes_session_token(cheese_bytes) do
    {token, cheese_bytes_token} = CheeseBytesToken.build_session_token(cheese_bytes)
    Repo.insert!(cheese_bytes_token)
    token
  end

  @doc """
  Gets the cheese_bytes with the given signed token.

  If the token is valid `{cheese_bytes, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_cheese_bytes_by_session_token(token) do
    {:ok, query} = CheeseBytesToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the cheese_bytes with the given magic link token.
  """
  def get_cheese_bytes_by_magic_link_token(token) do
    with {:ok, query} <- CheeseBytesToken.verify_magic_link_token_query(token),
         {cheese_bytes, _token} <- Repo.one(query) do
      cheese_bytes
    else
      _ -> nil
    end
  end

  @doc """
  Logs the cheese_bytes in by magic link.

  There are three cases to consider:

  1. The cheese_bytes has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The cheese_bytes has not confirmed their email and no password is set.
     In this case, the cheese_bytes gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The cheese_bytes has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_cheese_bytes_by_magic_link(token) do
    {:ok, query} = CheeseBytesToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%CheeseBytes{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%CheeseBytes{confirmed_at: nil} = cheese_bytes, _token} ->
        cheese_bytes
        |> CheeseBytes.confirm_changeset()
        |> update_cheese_bytes_and_delete_all_tokens()

      {cheese_bytes, token} ->
        Repo.delete!(token)
        {:ok, cheese_bytes, []}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given cheese_bytes.

  ## Examples

      iex> deliver_cheese_bytes_update_email_instructions(cheese_bytes, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_cheese_bytes_update_email_instructions(%CheeseBytes{} = cheese_bytes, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, cheese_bytes_token} = CheeseBytesToken.build_email_token(cheese_bytes, "change:#{current_email}")

    Repo.insert!(cheese_bytes_token)
    CheeseBytesNotifier.deliver_update_email_instructions(cheese_bytes, update_email_url_fun.(encoded_token))
  end

  @doc ~S"""
  Delivers the magic link login instructions to the given cheese_bytes.
  """
  def deliver_login_instructions(%CheeseBytes{} = cheese_bytes, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, cheese_bytes_token} = CheeseBytesToken.build_email_token(cheese_bytes, "login")
    Repo.insert!(cheese_bytes_token)
    CheeseBytesNotifier.deliver_login_instructions(cheese_bytes, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_cheese_bytes_session_token(token) do
    Repo.delete_all(CheeseBytesToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Token helper

  defp update_cheese_bytes_and_delete_all_tokens(changeset) do
    %{data: %CheeseBytes{} = cheese_bytes} = changeset

    with {:ok, %{cheese_bytes: cheese_bytes, tokens_to_expire: expired_tokens}} <-
           Ecto.Multi.new()
           |> Ecto.Multi.update(:cheese_bytes, changeset)
           |> Ecto.Multi.all(:tokens_to_expire, CheeseBytesToken.by_cheese_bytes_and_contexts_query(cheese_bytes, :all))
           |> Ecto.Multi.delete_all(:tokens, fn %{tokens_to_expire: tokens_to_expire} ->
             CheeseBytesToken.delete_all_query(tokens_to_expire)
           end)
           |> Repo.transaction() do
      {:ok, cheese_bytes, expired_tokens}
    end
  end
end
