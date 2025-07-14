defmodule MascarponeWeb.CheeseBytesSessionControllerTest do
  use MascarponeWeb.ConnCase, async: true

  import Mascarpone.AccountsFixtures
  alias Mascarpone.Accounts

  setup do
    %{unconfirmed_cheese_bytes: unconfirmed_cheese_bytes_fixture(), cheese_bytes: cheese_bytes_fixture()}
  end

  describe "POST /users/log-in - email and password" do
    test "logs the cheese_bytes in", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes = set_password(cheese_bytes)

      conn =
        post(conn, ~p"/users/log-in", %{
          "cheese_bytes" => %{"email" => cheese_bytes.email, "password" => valid_cheese_bytes_password()}
        })

      assert get_session(conn, :cheese_bytes_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ cheese_bytes.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "logs the cheese_bytes in with remember me", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes = set_password(cheese_bytes)

      conn =
        post(conn, ~p"/users/log-in", %{
          "cheese_bytes" => %{
            "email" => cheese_bytes.email,
            "password" => valid_cheese_bytes_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_mascarpone_web_cheese_bytes_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the cheese_bytes in with return to", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes = set_password(cheese_bytes)

      conn =
        conn
        |> init_test_session(cheese_bytes_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "cheese_bytes" => %{
            "email" => cheese_bytes.email,
            "password" => valid_cheese_bytes_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "cheese_bytes" => %{"email" => cheese_bytes.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "logs the cheese_bytes in", %{conn: conn, cheese_bytes: cheese_bytes} do
      {token, _hashed_token} = generate_cheese_bytes_magic_link_token(cheese_bytes)

      conn =
        post(conn, ~p"/users/log-in", %{
          "cheese_bytes" => %{"token" => token}
        })

      assert get_session(conn, :cheese_bytes_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ cheese_bytes.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "confirms unconfirmed cheese_bytes", %{conn: conn, unconfirmed_cheese_bytes: cheese_bytes} do
      {token, _hashed_token} = generate_cheese_bytes_magic_link_token(cheese_bytes)
      refute cheese_bytes.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "cheese_bytes" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :cheese_bytes_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Cheese bytes confirmed successfully."

      assert Accounts.get_cheese_bytes!(cheese_bytes.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ cheese_bytes.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "cheese_bytes" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the cheese_bytes out", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn = conn |> log_in_cheese_bytes(cheese_bytes) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :cheese_bytes_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the cheese_bytes is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :cheese_bytes_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
