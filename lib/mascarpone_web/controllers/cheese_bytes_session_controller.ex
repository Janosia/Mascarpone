defmodule MascarponeWeb.CheeseBytesSessionController do
  use MascarponeWeb, :controller

  alias Mascarpone.Accounts
  alias MascarponeWeb.CheeseBytesAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Cheese bytes confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"cheese_bytes" => %{"token" => token} = cheese_bytes_params}, info) do
    case Accounts.login_cheese_bytes_by_magic_link(token) do
      {:ok, cheese_bytes, tokens_to_disconnect} ->
        CheeseBytesAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, cheese_bytes_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"cheese_bytes" => cheese_bytes_params}, info) do
    %{"email" => email, "password" => password} = cheese_bytes_params

    if cheese_bytes = Accounts.get_cheese_bytes_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> CheeseBytesAuth.log_in_cheese_bytes(cheese_bytes, cheese_bytes_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"cheese_bytes" => cheese_bytes_params} = params) do
    cheese_bytes = conn.assigns.current_scope.cheese_bytes
    true = Accounts.sudo_mode?(cheese_bytes)
    {:ok, _cheese_bytes, expired_tokens} = Accounts.update_cheese_bytes_password(cheese_bytes, cheese_bytes_params)

    # disconnect all existing LiveViews with old sessions
    CheeseBytesAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:cheese_bytes_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> CheeseBytesAuth.log_out_cheese_bytes()
  end
end
