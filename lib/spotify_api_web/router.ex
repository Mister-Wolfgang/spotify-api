defmodule SpotifyApiWeb.Router do
  use SpotifyApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SpotifyApiWeb do
    pipe_through :api
  end
end
