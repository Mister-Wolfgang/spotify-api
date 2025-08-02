defmodule SpotifyApi.Cache.Strategies do
  @moduledoc """
  Stratégies avancées de cache pour optimiser les performances.
  Compatible avec Cachex v3.6
  """

  require Logger

  @doc """
  Cache warming: pré-charge le cache avec des artistes populaires.
  """
  def warm_popular_artists do
    popular_artists = [
      "The Beatles", "Queen", "Led Zeppelin", "Pink Floyd", "AC/DC",
      "The Rolling Stones", "Nirvana", "Radiohead", "Metallica", "U2"
    ]

    Task.async_stream(popular_artists, &warm_artist_cache/1,
      max_concurrency: 3,
      timeout: 30_000
    )
    |> Stream.run()

    Logger.info("Cache warming completed for #{length(popular_artists)} popular artists")
  end

  @doc """
  Cache refresh: actualise les entrées qui vont bientôt expirer.
  """
  def refresh_expiring_entries do
    # Cette fonction serait appelée périodiquement
    # Dans un vrai système, on garderait track des TTL
    Logger.info("Refreshing expiring cache entries")
  end

  @doc """
  Analyse les patterns d'utilisation du cache.
  """
  def analyze_cache_patterns do
    case Cachex.stats(:spotify_cache) do
      {:ok, stats} ->
        analysis = calculate_cache_analysis(stats)
        Logger.info("Cache analysis: #{inspect(analysis)}")

        # Recommandations basées sur l'analyse
        recommendations = generate_recommendations(analysis)
        Logger.info("Cache recommendations: #{inspect(recommendations)}")

        analysis

      {:error, reason} ->
        Logger.error("Cache stats error: #{inspect(reason)}")
        %{error: reason}
    end
  end

  # Fonctions privées
  defp warm_artist_cache(artist_name) do
    try do
      case SpotifyApi.Features.ArtistAlbums.get_albums(artist_name) do
        {:ok, _albums} ->
          Logger.debug("Warmed cache for artist: #{artist_name}")
          :ok

        {:error, reason} ->
          Logger.warning("Failed to warm cache for #{artist_name}: #{inspect(reason)}")
          :error
      end
    rescue
      error ->
        Logger.error("Error warming cache for #{artist_name}: #{inspect(error)}")
        :error
    end
  end

  defp calculate_cache_analysis(stats) do
    hit_count = Map.get(stats, :hit_count, 0)
    miss_count = Map.get(stats, :miss_count, 0)
    eviction_count = Map.get(stats, :eviction_count, 0)

    hit_rate = case hit_count + miss_count do
      0 -> 0.0
      total -> (hit_count / total * 100) |> Float.round(2)
    end

    %{
      hit_rate_percent: hit_rate,
      total_requests: hit_count + miss_count,
      evictions: eviction_count,
      hits: hit_count,
      misses: miss_count
    }
  end

  defp generate_recommendations(analysis) do
    recommendations = []

    recommendations = if analysis.hit_rate_percent < 70 do
      ["Consider increasing cache TTL or implementing cache warming" | recommendations]
    else
      recommendations
    end

    recommendations = if analysis.evictions > 100 do
      ["Consider increasing cache size limit" | recommendations]
    else
      recommendations
    end

    case recommendations do
      [] -> ["Cache performance looks good"]
      recs -> recs
    end
  end
end
