defmodule MascarponeWeb.CheeseBytesLive.LoginTest do
  use MascarponeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mascarpone.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert html =~ "Register"
      assert html =~ "Log in with email"
    end
  end

  describe "cheese_bytes login - magic link" do
    test "sends magic link email when cheese_bytes exists", %{conn: conn} do
      cheese_bytes = cheese_bytes_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", cheese_bytes: %{email: cheese_bytes.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"

      assert Mascarpone.Repo.get_by!(Mascarpone.Accounts.CheeseBytesToken, cheese_bytes_id: cheese_bytes.id).context ==
               "login"
    end

    test "does not disclose if cheese_bytes is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", cheese_bytes: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "cheese_bytes login - password" do
    test "redirects if cheese_bytes logs in with valid credentials", %{conn: conn} do
      cheese_bytes = cheese_bytes_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          cheese_bytes: %{email: cheese_bytes.email, password: valid_cheese_bytes_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          cheese_bytes: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      render_submit(form)

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert login_html =~ "Register"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      cheese_bytes = cheese_bytes_fixture()
      %{cheese_bytes: cheese_bytes, conn: log_in_cheese_bytes(conn, cheese_bytes)}
    end

    test "shows login page with email filled in", %{conn: conn, cheese_bytes: cheese_bytes} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "You need to reauthenticate"
      refute html =~ "Register"
      assert html =~ "Log in with email"

      assert html =~
               ~s(<input type="email" name="cheese_bytes[email]" id="login_form_magic_email" value="#{cheese_bytes.email}")
    end
  end
end
