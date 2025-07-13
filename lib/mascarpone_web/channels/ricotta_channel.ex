defmodule MascarponeWeb.RicottaChannel do
  use MascarponeWeb, :channel

  @impl true
  def join("ricotta:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (ricotta:lobby).
  @impl true
  def handle_in("new message", payload, socket) do
    broadcast! socket, "new message",payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
