defmodule Mascarpone.Accounts.CheeseBytesNotifier do
  import Swoosh.Email

  alias Mascarpone.Mailer
  alias Mascarpone.Accounts.CheeseBytes

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Mascarpone", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a cheese_bytes email.
  """
  def deliver_update_email_instructions(cheese_bytes, url) do
    deliver(cheese_bytes.email, "Update email instructions", """

    ==============================

    Hi #{cheese_bytes.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(cheese_bytes, url) do
    case cheese_bytes do
      %CheeseBytes{confirmed_at: nil} -> deliver_confirmation_instructions(cheese_bytes, url)
      _ -> deliver_magic_link_instructions(cheese_bytes, url)
    end
  end

  defp deliver_magic_link_instructions(cheese_bytes, url) do
    deliver(cheese_bytes.email, "Log in instructions", """

    ==============================

    Hi #{cheese_bytes.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(cheese_bytes, url) do
    deliver(cheese_bytes.email, "Confirmation instructions", """

    ==============================

    Hi #{cheese_bytes.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
