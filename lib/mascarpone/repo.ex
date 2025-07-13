defmodule Mascarpone.Repo do
  use Ecto.Repo,
    otp_app: :mascarpone,
    adapter: Ecto.Adapters.Postgres
end
