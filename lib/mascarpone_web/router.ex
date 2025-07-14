defmodule MascarponeWeb.Router do
  use MascarponeWeb, :router

  import MascarponeWeb.CheeseBytesAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MascarponeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_cheese_bytes
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MascarponeWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", MascarponeWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mascarpone, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MascarponeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MascarponeWeb do
    pipe_through [:browser, :require_authenticated_cheese_bytes]

    live_session :require_authenticated_cheese_bytes,
      on_mount: [{MascarponeWeb.CheeseBytesAuth, :require_authenticated}] do
      live "/users/settings", CheeseBytesLive.Settings, :edit
      live "/users/settings/confirm-email/:token", CheeseBytesLive.Settings, :confirm_email
    end

    post "/users/update-password", CheeseBytesSessionController, :update_password
  end

  scope "/", MascarponeWeb do
    pipe_through [:browser]

    live_session :current_cheese_bytes,
      on_mount: [{MascarponeWeb.CheeseBytesAuth, :mount_current_scope}] do
      live "/users/register", CheeseBytesLive.Registration, :new
      live "/users/log-in", CheeseBytesLive.Login, :new
      live "/users/log-in/:token", CheeseBytesLive.Confirmation, :new
    end

    post "/users/log-in", CheeseBytesSessionController, :create
    delete "/users/log-out", CheeseBytesSessionController, :delete
  end
end
