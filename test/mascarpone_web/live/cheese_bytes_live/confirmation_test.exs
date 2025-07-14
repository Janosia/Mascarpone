defmodule MascarponeWeb.CheeseBytesLive.ConfirmationTest do
  use MascarponeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mascarpone.AccountsFixtures

  alias Mascarpone.Accounts

  setup do
    %{unconfirmed_cheese_bytes: unconfirmed_cheese_bytes_fixture(), confirmed_cheese_bytes: cheese_bytes_fixture()}
  end

  describe "Confirm cheese_bytes" do
    test "renders confirmation page for unconfirmed cheese_bytes", %{conn: conn, unconfirmed_cheese_bytes: cheese_bytes} do
      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_login_instructions(cheese_bytes, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      assert html =~ "Confirm my account"
    end

    test "renders login page for confirmed cheese_bytes", %{conn: conn, confirmed_cheese_bytes: cheese_bytes} do
      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_login_instructions(cheese_bytes, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_cheese_bytes: cheese_bytes} do
      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_login_instructions(cheese_bytes, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"cheese_bytes" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "CheeseBytes confirmed successfully"

      assert Accounts.get_cheese_bytes!(cheese_bytes.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :cheese_bytes_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed cheese_bytes in without changing confirmed_at", %{
      conn: conn,
      confirmed_cheese_bytes: cheese_bytes
    } do
      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_login_instructions(cheese_bytes, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#login_form", %{"cheese_bytes" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Accounts.get_cheese_bytes!(cheese_bytes.id).confirmed_at == cheese_bytes.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
