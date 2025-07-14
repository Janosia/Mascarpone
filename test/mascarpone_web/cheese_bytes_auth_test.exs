defmodule MascarponeWeb.CheeseBytesAuthTest do
  use MascarponeWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Mascarpone.Accounts
  alias Mascarpone.Accounts.Scope
  alias MascarponeWeb.CheeseBytesAuth

  import Mascarpone.AccountsFixtures

  @remember_me_cookie "_mascarpone_web_cheese_bytes_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MascarponeWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{cheese_bytes: %{cheese_bytes_fixture() | authenticated_at: DateTime.utc_now(:second)}, conn: conn}
  end

  describe "log_in_cheese_bytes/3" do
    test "stores the cheese_bytes token in the session", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn = CheeseBytesAuth.log_in_cheese_bytes(conn, cheese_bytes)
      assert token = get_session(conn, :cheese_bytes_token)
      assert get_session(conn, :live_socket_id) == "users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_cheese_bytes_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn = conn |> put_session(:to_be_removed, "value") |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes)
      refute get_session(conn, :to_be_removed)
    end

    test "keeps session when re-authenticating", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_cheese_bytes(cheese_bytes))
        |> put_session(:to_be_removed, "value")
        |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes)

      assert get_session(conn, :to_be_removed)
    end

    test "clears session when cheese_bytes does not match when re-authenticating", %{
      conn: conn,
      cheese_bytes: cheese_bytes
    } do
      other_cheese_bytes = cheese_bytes_fixture()

      conn =
        conn
        |> assign(:current_scope, Scope.for_cheese_bytes(other_cheese_bytes))
        |> put_session(:to_be_removed, "value")
        |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn = conn |> put_session(:cheese_bytes_return_to, "/hello") |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn = conn |> fetch_cookies() |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, %{"remember_me" => "true"})
      assert get_session(conn, :cheese_bytes_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :cheese_bytes_remember_me) == true

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :cheese_bytes_token)
      assert max_age == @remember_me_cookie_max_age
    end

    test "redirects to settings when cheese_bytes is already logged in", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_cheese_bytes(cheese_bytes))
        |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes)

      assert redirected_to(conn) == "/users/settings"
    end

    test "writes a cookie if remember_me was set in previous session", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn = conn |> fetch_cookies() |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, %{"remember_me" => "true"})
      assert get_session(conn, :cheese_bytes_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :cheese_bytes_remember_me) == true

      conn =
        conn
        |> recycle()
        |> Map.replace!(:secret_key_base, MascarponeWeb.Endpoint.config(:secret_key_base))
        |> fetch_cookies()
        |> init_test_session(%{cheese_bytes_remember_me: true})

      # the conn is already logged in and has the remember_me cookie set,
      # now we log in again and even without explicitly setting remember_me,
      # the cookie should be set again
      conn = conn |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, %{})
      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :cheese_bytes_token)
      assert max_age == @remember_me_cookie_max_age
      assert get_session(conn, :cheese_bytes_remember_me) == true
    end
  end

  describe "logout_cheese_bytes/1" do
    test "erases session and cookies", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes_token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)

      conn =
        conn
        |> put_session(:cheese_bytes_token, cheese_bytes_token)
        |> put_req_cookie(@remember_me_cookie, cheese_bytes_token)
        |> fetch_cookies()
        |> CheeseBytesAuth.log_out_cheese_bytes()

      refute get_session(conn, :cheese_bytes_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_cheese_bytes_by_session_token(cheese_bytes_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "users_sessions:abcdef-token"
      MascarponeWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> CheeseBytesAuth.log_out_cheese_bytes()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if cheese_bytes is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> CheeseBytesAuth.log_out_cheese_bytes()
      refute get_session(conn, :cheese_bytes_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_scope_for_cheese_bytes/2" do
    test "authenticates cheese_bytes from session", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes_token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)

      conn =
        conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> CheeseBytesAuth.fetch_current_scope_for_cheese_bytes([])

      assert conn.assigns.current_scope.cheese_bytes.id == cheese_bytes.id
      assert conn.assigns.current_scope.cheese_bytes.authenticated_at == cheese_bytes.authenticated_at
      assert get_session(conn, :cheese_bytes_token) == cheese_bytes_token
    end

    test "authenticates cheese_bytes from cookies", %{conn: conn, cheese_bytes: cheese_bytes} do
      logged_in_conn =
        conn |> fetch_cookies() |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, %{"remember_me" => "true"})

      cheese_bytes_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> CheeseBytesAuth.fetch_current_scope_for_cheese_bytes([])

      assert conn.assigns.current_scope.cheese_bytes.id == cheese_bytes.id
      assert conn.assigns.current_scope.cheese_bytes.authenticated_at == cheese_bytes.authenticated_at
      assert get_session(conn, :cheese_bytes_token) == cheese_bytes_token
      assert get_session(conn, :cheese_bytes_remember_me)

      assert get_session(conn, :live_socket_id) ==
               "users_sessions:#{Base.url_encode64(cheese_bytes_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, cheese_bytes: cheese_bytes} do
      _ = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      conn = CheeseBytesAuth.fetch_current_scope_for_cheese_bytes(conn, [])
      refute get_session(conn, :cheese_bytes_token)
      refute conn.assigns.current_scope
    end

    test "reissues a new token after a few days and refreshes cookie", %{conn: conn, cheese_bytes: cheese_bytes} do
      logged_in_conn =
        conn |> fetch_cookies() |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, %{"remember_me" => "true"})

      token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      offset_cheese_bytes_token(token, -10, :day)
      {cheese_bytes, _} = Accounts.get_cheese_bytes_by_session_token(token)

      conn =
        conn
        |> put_session(:cheese_bytes_token, token)
        |> put_session(:cheese_bytes_remember_me, true)
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> CheeseBytesAuth.fetch_current_scope_for_cheese_bytes([])

      assert conn.assigns.current_scope.cheese_bytes.id == cheese_bytes.id
      assert conn.assigns.current_scope.cheese_bytes.authenticated_at == cheese_bytes.authenticated_at
      assert new_token = get_session(conn, :cheese_bytes_token)
      assert new_token != token
      assert %{value: new_signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert new_signed_token != signed_token
      assert max_age == @remember_me_cookie_max_age
    end
  end

  describe "on_mount :mount_current_scope" do
    setup %{conn: conn} do
      %{conn: CheeseBytesAuth.fetch_current_scope_for_cheese_bytes(conn, [])}
    end

    test "assigns current_scope based on a valid cheese_bytes_token", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes_token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      session = conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> get_session()

      {:cont, updated_socket} =
        CheeseBytesAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.cheese_bytes.id == cheese_bytes.id
    end

    test "assigns nil to current_scope assign if there isn't a valid cheese_bytes_token", %{conn: conn} do
      cheese_bytes_token = "invalid_token"
      session = conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> get_session()

      {:cont, updated_socket} =
        CheeseBytesAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end

    test "assigns nil to current_scope assign if there isn't a cheese_bytes_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        CheeseBytesAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "authenticates current_scope based on a valid cheese_bytes_token", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes_token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      session = conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> get_session()

      {:cont, updated_socket} =
        CheeseBytesAuth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.cheese_bytes.id == cheese_bytes.id
    end

    test "redirects to login page if there isn't a valid cheese_bytes_token", %{conn: conn} do
      cheese_bytes_token = "invalid_token"
      session = conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: MascarponeWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = CheeseBytesAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_scope == nil
    end

    test "redirects to login page if there isn't a cheese_bytes_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: MascarponeWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = CheeseBytesAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_sudo_mode" do
    test "allows users that have authenticated in the last 10 minutes", %{conn: conn, cheese_bytes: cheese_bytes} do
      cheese_bytes_token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      session = conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: MascarponeWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:cont, _updated_socket} =
               CheeseBytesAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end

    test "redirects when authentication is too old", %{conn: conn, cheese_bytes: cheese_bytes} do
      eleven_minutes_ago = DateTime.utc_now(:second) |> DateTime.add(-11, :minute)
      cheese_bytes = %{cheese_bytes | authenticated_at: eleven_minutes_ago}
      cheese_bytes_token = Accounts.generate_cheese_bytes_session_token(cheese_bytes)
      {cheese_bytes, token_inserted_at} = Accounts.get_cheese_bytes_by_session_token(cheese_bytes_token)
      assert DateTime.compare(token_inserted_at, cheese_bytes.authenticated_at) == :gt
      session = conn |> put_session(:cheese_bytes_token, cheese_bytes_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: MascarponeWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _updated_socket} =
               CheeseBytesAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end
  end

  describe "require_authenticated_cheese_bytes/2" do
    setup %{conn: conn} do
      %{conn: CheeseBytesAuth.fetch_current_scope_for_cheese_bytes(conn, [])}
    end

    test "redirects if cheese_bytes is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> CheeseBytesAuth.require_authenticated_cheese_bytes([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> CheeseBytesAuth.require_authenticated_cheese_bytes([])

      assert halted_conn.halted
      assert get_session(halted_conn, :cheese_bytes_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> CheeseBytesAuth.require_authenticated_cheese_bytes([])

      assert halted_conn.halted
      assert get_session(halted_conn, :cheese_bytes_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> CheeseBytesAuth.require_authenticated_cheese_bytes([])

      assert halted_conn.halted
      refute get_session(halted_conn, :cheese_bytes_return_to)
    end

    test "does not redirect if cheese_bytes is authenticated", %{conn: conn, cheese_bytes: cheese_bytes} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_cheese_bytes(cheese_bytes))
        |> CheeseBytesAuth.require_authenticated_cheese_bytes([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect messages for each token" do
      tokens = [%{token: "token1"}, %{token: "token2"}]

      for %{token: token} <- tokens do
        MascarponeWeb.Endpoint.subscribe("users_sessions:#{Base.url_encode64(token)}")
      end

      CheeseBytesAuth.disconnect_sessions(tokens)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "users_sessions:dG9rZW4x"
      }

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "users_sessions:dG9rZW4y"
      }
    end
  end
end
