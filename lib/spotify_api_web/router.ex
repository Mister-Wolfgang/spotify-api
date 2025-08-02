
defmodule SpotifyApiWeb.Router do
  use SpotifyApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :put_secure_browser_headers

    # Rate limiting per IP
    plug SpotifyApiWeb.Plugs.RateLimiter

    # Request logging
    plug SpotifyApiWeb.Plugs.RequestLogger

    # OpenAPI validation
    plug OpenApiSpex.Plug.PutApiSpec, module: SpotifyApiWeb.ApiSpec
  end

  pipeline :swagger do
    plug :accepts, ["json", "html"]
    plug OpenApiSpex.Plug.PutApiSpec, module: SpotifyApiWeb.ApiSpec
  end

  # Documentation Swagger
  scope "/docs" do
    pipe_through :swagger
    get "/", OpenApiSpex.Plug.SwaggerUI, path: "/docs/openapi"
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  # Health check (sans rate limiting)
  scope "/health" do
    pipe_through []
    get "/", SpotifyApiWeb.HealthController, :index
  end

  # API routes
  scope "/api", SpotifyApiWeb do
    pipe_through :api

    # Version 1 de l'API
    scope "/v1" do
      get "/artists/:name/albums", ArtistAlbumsController, :index
    end
  end

  # Fallback route pour 404
  scope "/" do
    match :*, "/*path", SpotifyApiWeb.FallbackController, :not_found
  end
end
