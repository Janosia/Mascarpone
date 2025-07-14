defmodule Mascarpone.AccountsTest do
  use Mascarpone.DataCase

  alias Mascarpone.Accounts

  import Mascarpone.AccountsFixtures
  alias Mascarpone.Accounts.{CheeseBytes, CheeseBytesToken}

  describe "get_cheese_bytes_by_email/1" do
    test "does not return the cheese_bytes if the email does not exist" do
      refute Accounts.get_cheese_bytes_by_email("unknown@example.com")
    end

    test "returns the cheese_bytes if the email exists" do
      %{id: id} = cheese_bytes = cheese_bytes_fixture()
      assert %CheeseBytes{id: ^id} = Accounts.get_cheese_bytes_by_email(cheese_bytes.email)
    end
  end

  describe "get_cheese_bytes_by_email_and_password/2" do
    test "does not return the cheese_bytes if the email does not exist" do
      refute Accounts.get_cheese_bytes_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the cheese_bytes if the password is not valid" do
      cheese_bytes = cheese_bytes_fixture() |> set_password()
      refute Accounts.get_cheese_bytes_by_email_and_password(cheese_bytes.email, "invalid")
    end

    test "returns the cheese_bytes if the email and password are valid" do
      %{id: id} = cheese_bytes = cheese_bytes_fixture() |> set_password()

      assert %CheeseBytes{id: ^id} =
               Accounts.get_cheese_bytes_by_email_and_password(cheese_bytes.email, valid_cheese_bytes_password())
    end
  end

  describe "get_cheese_bytes!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_cheese_bytes!(-1)
      end
    end

    test "returns the cheese_bytes with the given id" do
      %{id: id} = cheese_bytes = cheese_bytes_fixture()
      assert %CheeseBytes{id: ^id} = Accounts.get_cheese_bytes!(cheese_bytes.id)
    end
  end

  describe "register_cheese_bytes/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_cheese_bytes(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_cheese_bytes(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_cheese_bytes(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = cheese_bytes_fixture()
      {:error, changeset} = Accounts.register_cheese_bytes(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_cheese_bytes(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_cheese_bytes_email()
      {:ok, cheese_bytes} = Accounts.register_cheese_bytes(valid_cheese_bytes_attributes(email: email))
      assert cheese_bytes.email == email
      assert is_nil(cheese_bytes.hashed_password)
      assert is_nil(cheese_bytes.confirmed_at)
      assert is_nil(cheese_bytes.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%CheeseBytes{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%CheeseBytes{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%CheeseBytes{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %CheeseBytes{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%CheeseBytes{})
    end
  end

  describe "change_cheese_bytes_email/3" do
    test "returns a cheese_bytes changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_cheese_bytes_email(%CheeseBytes{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_cheese_bytes_update_email_instructions/3" do
    setup do
      %{cheese_bytes: cheese_bytes_fixture()}
    end

    test "sends token through notification", %{cheese_bytes: cheese_bytes} do
      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_cheese_bytes_update_email_instructions(cheese_bytes, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert cheese_bytes_token = Repo.get_by(CheeseBytesToken, token: :crypto.hash(:sha256, token))
      assert cheese_bytes_token.cheese_bytes_id == cheese_bytes.id
      assert cheese_bytes_token.sent_to == cheese_bytes.email
      assert cheese_bytes_token.context == "change:current@example.com"
    end
  end

  describe "update_cheese_bytes_email/2" do
    setup do
      cheese_bytes = unconfirmed_cheese_bytes_fixture()
      email = unique_cheese_bytes_email()

      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_cheese_bytes_update_email_instructions(%{cheese_bytes | email: email}, cheese_bytes.email, url)
        end)

      %{cheese_bytes: cheese_bytes, token: token, email: email}
    end

    test "updates the email with a valid token", %{cheese_bytes: cheese_bytes, token: token, email: email} do
      assert Accounts.update_cheese_bytes_email(cheese_bytes, token) == :ok
      changed_cheese_bytes = Repo.get!(CheeseBytes, cheese_bytes.id)
      assert changed_cheese_bytes.email != cheese_bytes.email
      assert changed_cheese_bytes.email == email
      refute Repo.get_by(CheeseBytesToken, cheese_bytes_id: cheese_bytes.id)
    end

    test "does not update email with invalid token", %{cheese_bytes: cheese_bytes} do
      assert Accounts.update_cheese_bytes_email(cheese_bytes, "oops") == :error
      assert Repo.get!(CheeseBytes, cheese_bytes.id).email == cheese_bytes.email
      assert Repo.get_by(CheeseBytesToken, cheese_bytes_id: cheese_bytes.id)
    end

    test "does not update email if cheese_bytes email changed", %{cheese_bytes: cheese_bytes, token: token} do
      assert Accounts.update_cheese_bytes_email(%{cheese_bytes | email: "current@example.com"}, token) == :error
      assert Repo.get!(CheeseBytes, cheese_bytes.id).email == cheese_bytes.email
      assert Repo.get_by(CheeseBytesToken, cheese_bytes_id: cheese_bytes.id)
    end

    test "does not update email if token expired", %{cheese_bytes: cheese_bytes, token: token} do
      {1, nil} = Repo.update_all(CheeseBytesToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_cheese_bytes_email(cheese_bytes, token) == :error
      assert Repo.get!(CheeseBytes, cheese_bytes.id).email == cheese_bytes.email
      assert Repo.get_by(CheeseBytesToken, cheese_bytes_id: cheese_bytes.id)
    end
  end

  describe "change_cheese_bytes_password/3" do
    test "returns a cheese_bytes changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_cheese_bytes_password(%CheeseBytes{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_cheese_bytes_password(
          %CheeseBytes{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_cheese_bytes_password/2" do
    setup do
      %{cheese_bytes: cheese_bytes_fixture()}
    end

    test "validates password", %{cheese_bytes: cheese_bytes} do
      {:error, changeset} =
        Accounts.update_cheese_bytes_password(cheese_bytes, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{cheese_bytes: cheese_bytes} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_cheese_bytes_password(cheese_bytes, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{cheese_bytes: cheese_bytes} do
      {:ok, cheese_bytes, expired_tokens} =
        Accounts.update_cheese_bytes_password(cheese_bytes, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(cheese_bytes.password)
      assert Accounts.get_cheese_bytes_by_email_and_password(cheese_bytes.email, "new valid password")
    end

    test "deletes all tokens for the given cheese_bytes", %{cheese_bytes: cheese_bytes} do
      _ = Accounts.generate_cheese_bytes_session_token(cheese_bytes)

      {:ok, _, _} =
        Accounts.update_cheese_bytes_password(cheese_bytes, %{
          password: "new valid password"
        })

      refute Repo.get_by(CheeseBytesToken, cheese_bytes_id: cheese_bytes.id)
    end
  end

  describe "generate_cheese_bytes_session_token/1" do
    setup do
      %{cheese_bytes: cheese_bytes_fixture()}
    end

    test "generates a token", %{cheese_bytes: cheese_bytes} do
      token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      assert cheese_bytes_token = Repo.get_by(CheeseBytesToken, token: token)
      assert cheese_bytes_token.context == "session"
      assert cheese_bytes_token.authenticated_at != nil

      # Creating the same token for another cheese_bytes should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%CheeseBytesToken{
          token: cheese_bytes_token.token,
          cheese_bytes_id: cheese_bytes_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given cheese_bytes in new token", %{cheese_bytes: cheese_bytes} do
      cheese_bytes = %{cheese_bytes | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      assert cheese_bytes_token = Repo.get_by(CheeseBytesToken, token: token)
      assert cheese_bytes_token.authenticated_at == cheese_bytes.authenticated_at
      assert DateTime.compare(cheese_bytes_token.inserted_at, cheese_bytes.authenticated_at) == :gt
    end
  end

  describe "get_cheese_bytes_by_session_token/1" do
    setup do
      cheese_bytes = cheese_bytes_fixture()
      token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      %{cheese_bytes: cheese_bytes, token: token}
    end

    test "returns cheese_bytes by token", %{cheese_bytes: cheese_bytes, token: token} do
      assert {session_cheese_bytes, token_inserted_at} = Accounts.get_cheese_bytes_by_session_token(token)
      assert session_cheese_bytes.id == cheese_bytes.id
      assert session_cheese_bytes.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return cheese_bytes for invalid token" do
      refute Accounts.get_cheese_bytes_by_session_token("oops")
    end

    test "does not return cheese_bytes for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(CheeseBytesToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_cheese_bytes_by_session_token(token)
    end
  end

  describe "get_cheese_bytes_by_magic_link_token/1" do
    setup do
      cheese_bytes = cheese_bytes_fixture()
      {encoded_token, _hashed_token} = generate_cheese_bytes_magic_link_token(cheese_bytes)
      %{cheese_bytes: cheese_bytes, token: encoded_token}
    end

    test "returns cheese_bytes by token", %{cheese_bytes: cheese_bytes, token: token} do
      assert session_cheese_bytes = Accounts.get_cheese_bytes_by_magic_link_token(token)
      assert session_cheese_bytes.id == cheese_bytes.id
    end

    test "does not return cheese_bytes for invalid token" do
      refute Accounts.get_cheese_bytes_by_magic_link_token("oops")
    end

    test "does not return cheese_bytes for expired token", %{token: token} do
      {1, nil} = Repo.update_all(CheeseBytesToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_cheese_bytes_by_magic_link_token(token)
    end
  end

  describe "login_cheese_bytes_by_magic_link/1" do
    test "confirms cheese_bytes and expires tokens" do
      cheese_bytes = unconfirmed_cheese_bytes_fixture()
      refute cheese_bytes.confirmed_at
      {encoded_token, hashed_token} = generate_cheese_bytes_magic_link_token(cheese_bytes)

      assert {:ok, cheese_bytes, [%{token: ^hashed_token}]} =
               Accounts.login_cheese_bytes_by_magic_link(encoded_token)

      assert cheese_bytes.confirmed_at
    end

    test "returns cheese_bytes and (deleted) token for confirmed cheese_bytes" do
      cheese_bytes = cheese_bytes_fixture()
      assert cheese_bytes.confirmed_at
      {encoded_token, _hashed_token} = generate_cheese_bytes_magic_link_token(cheese_bytes)
      assert {:ok, ^cheese_bytes, []} = Accounts.login_cheese_bytes_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_cheese_bytes_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed cheese_bytes has password set" do
      cheese_bytes = unconfirmed_cheese_bytes_fixture()
      {1, nil} = Repo.update_all(CheeseBytes, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_cheese_bytes_magic_link_token(cheese_bytes)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_cheese_bytes_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_cheese_bytes_session_token/1" do
    test "deletes the token" do
      cheese_bytes = cheese_bytes_fixture()
      token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      assert Accounts.delete_cheese_bytes_session_token(token) == :ok
      refute Accounts.get_cheese_bytes_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{cheese_bytes: unconfirmed_cheese_bytes_fixture()}
    end

    test "sends token through notification", %{cheese_bytes: cheese_bytes} do
      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_login_instructions(cheese_bytes, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert cheese_bytes_token = Repo.get_by(CheeseBytesToken, token: :crypto.hash(:sha256, token))
      assert cheese_bytes_token.cheese_bytes_id == cheese_bytes.id
      assert cheese_bytes_token.sent_to == cheese_bytes.email
      assert cheese_bytes_token.context == "login"
    end
  end

  describe "inspect/2 for the CheeseBytes module" do
    test "does not include password" do
      refute inspect(%CheeseBytes{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
