defmodule MascarponeWeb.CheeseBytesLive.SettingsTest do
  use MascarponeWeb.ConnCase, async: true

  alias Mascarpone.Accounts
  import Phoenix.LiveViewTest
  import Mascarpone.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_cheese_bytes(cheese_bytes_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change Email"
      assert html =~ "Save Password"
    end

    test "redirects if cheese_bytes is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if cheese_bytes is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_cheese_bytes(cheese_bytes_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/settings")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      cheese_bytes = cheese_bytes_fixture()
      %{conn: log_in_cheese_bytes(conn, cheese_bytes), cheese_bytes: cheese_bytes}
    end

    test "updates the cheese_bytes email", %{conn: conn, cheese_bytes: cheese_bytes} do
      new_email = unique_cheese_bytes_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "cheese_bytes" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_cheese_bytes_by_email(cheese_bytes.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "cheese_bytes" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, cheese_bytes: cheese_bytes} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "cheese_bytes" => %{"email" => cheese_bytes.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      cheese_bytes = cheese_bytes_fixture()
      %{conn: log_in_cheese_bytes(conn, cheese_bytes), cheese_bytes: cheese_bytes}
    end

    test "updates the cheese_bytes password", %{conn: conn, cheese_bytes: cheese_bytes} do
      new_password = valid_cheese_bytes_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "cheese_bytes" => %{
            "email" => cheese_bytes.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :cheese_bytes_token) != get_session(conn, :cheese_bytes_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_cheese_bytes_by_email_and_password(cheese_bytes.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "cheese_bytes" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "cheese_bytes" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      cheese_bytes = cheese_bytes_fixture()
      email = unique_cheese_bytes_email()

      token =
        extract_cheese_bytes_token(fn url ->
          Accounts.deliver_cheese_bytes_update_email_instructions(%{cheese_bytes | email: email}, cheese_bytes.email, url)
        end)

      %{conn: log_in_cheese_bytes(conn, cheese_bytes), token: token, email: email, cheese_bytes: cheese_bytes}
    end

    test "updates the cheese_bytes email once", %{conn: conn, cheese_bytes: cheese_bytes, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_cheese_bytes_by_email(cheese_bytes.email)
      assert Accounts.get_cheese_bytes_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, cheese_bytes: cheese_bytes} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_cheese_bytes_by_email(cheese_bytes.email)
    end

    test "redirects if cheese_bytes is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
