defmodule MascarponeWeb.CheeseBytesLive.Settings do
  use MascarponeWeb, :live_view

  on_mount {MascarponeWeb.CheeseBytesAuth, :require_sudo_mode}

  alias Mascarpone.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header class="text-center">
        Account Settings
        <:subtitle>Manage your account email address and password settings</:subtitle>
      </.header>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_cheese_bytes_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_cheese_bytes_email(socket.assigns.current_scope.cheese_bytes, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    cheese_bytes = socket.assigns.current_scope.cheese_bytes
    email_changeset = Accounts.change_cheese_bytes_email(cheese_bytes, %{}, validate_email: false)
    password_changeset = Accounts.change_cheese_bytes_password(cheese_bytes, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, cheese_bytes.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"cheese_bytes" => cheese_bytes_params} = params

    email_form =
      socket.assigns.current_scope.cheese_bytes
      |> Accounts.change_cheese_bytes_email(cheese_bytes_params, validate_email: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"cheese_bytes" => cheese_bytes_params} = params
    cheese_bytes = socket.assigns.current_scope.cheese_bytes
    true = Accounts.sudo_mode?(cheese_bytes)

    case Accounts.change_cheese_bytes_email(cheese_bytes, cheese_bytes_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_cheese_bytes_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          cheese_bytes.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"cheese_bytes" => cheese_bytes_params} = params

    password_form =
      socket.assigns.current_scope.cheese_bytes
      |> Accounts.change_cheese_bytes_password(cheese_bytes_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"cheese_bytes" => cheese_bytes_params} = params
    cheese_bytes = socket.assigns.current_scope.cheese_bytes
    true = Accounts.sudo_mode?(cheese_bytes)

    case Accounts.change_cheese_bytes_password(cheese_bytes, cheese_bytes_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
