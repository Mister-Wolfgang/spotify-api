defmodule SpotifyApi.Cache.Supervisor do
  @moduledoc """
  Superviseur pour les processus de cache.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Cache principal avec options simplifiées
      {Cachex, name: :spotify_cache, options: cache_options()},

      # Worker pour les statistiques périodiques
      SpotifyApi.Cache.StatsWorker
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp cache_options do
    [
      # TTL par défaut
      default_ttl: :timer.minutes(30),

      # Limite de taille (nombre d'entrées)
      limit: 100_000,

      # Statistiques activées
      stats: true,

      # Expiration automatique
      expiration: [
        # Vérifier les expirations toutes les 30 secondes
        interval: :timer.seconds(30),
        # Nettoyer les entrées expirées de manière lazy
        lazy: true
      ]
    ]
  end
end
