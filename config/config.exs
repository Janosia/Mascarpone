# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mascarpone, :scopes,
  cheese_bytes: [
    default: true,
    module: Mascarpone.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:cheese_bytes, :id],
    schema_key: :cheese_bytes_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Mascarpone.AccountsFixtures,
    test_login_helper: :register_and_log_in_cheese_bytes
  ]

config :mascarpone,
  ecto_repos: [Mascarpone.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :mascarpone, MascarponeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MascarponeWeb.ErrorHTML, json: MascarponeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mascarpone.PubSub,
  live_view: [signing_salt: "BrgsrPX4"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mascarpone, Mascarpone.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  mascarpone: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  mascarpone: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
