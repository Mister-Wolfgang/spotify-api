defmodule SpotifyApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Charger les variables d'environnement depuis .env (sauf en production)
    unless Mix.env() == :prod do
      Dotenv.load()           # 1. Charge .env dans System.get_env()
      Mix.Task.run("loadconfig")  # 2. Recharge config/* avec les nouvelles variables
    end

    children = [
      # Telemetry supervisor
      SpotifyApiWeb.Telemetry,

      # Database repo
      SpotifyApi.Repo,

      # PubSub system
      {Phoenix.PubSub, name: SpotifyApi.PubSub},

      # Cache
      {Cachex, name: :spotify_cache},

      # Web endpoint
      SpotifyApiWeb.Endpoint
    ] ++ env_specific_children()

    opts = [strategy: :one_for_one, name: SpotifyApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Enfants spécifiques à l'environnement
  defp env_specific_children do
    case Mix.env() do
      :test -> []  # Pas de services externes en mode test
      _ -> [
        # Rate Limiter
        SpotifyApi.RateLimiter,

        # Spotify Auth Manager
        SpotifyApi.Spotify.AuthManager
      ]
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    SpotifyApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
