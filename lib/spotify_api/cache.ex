defmodule SpotifyApi.Cache do
  @moduledoc """
  Module de cache pour l'API Spotify.
  Utilise Cachex pour le stockage avec TTL automatique.
  """

  require Logger

  @cache_name :spotify_cache
  @default_ttl :timer.minutes(30)

  # TTL spécifiques par type de données
  @artist_albums_ttl :timer.hours(6)
  @artist_search_ttl :timer.hours(2)

  @doc """
  Récupère une valeur du cache.
  """
  def get(key) do
    case Cachex.get(@cache_name, key) do
      {:ok, nil} -> nil
      {:ok, value} -> value
      {:error, reason} ->
        Logger.error("Cache get error for key #{key}: #{inspect(reason)}")
        nil
    end
  end

  @doc """
  Stocke une valeur dans le cache avec un TTL optionnel.
  """
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    case Cachex.put(@cache_name, key, value, ttl: ttl) do
      {:ok, true} ->
        Logger.debug("Cached key: #{key} with TTL: #{ttl}ms")
        :ok
      {:error, reason} ->
        Logger.error("Cache put error for key #{key}: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Récupère une valeur du cache ou l'obtient via une fonction.
  Si la valeur n'est pas en cache, appelle la fonction et cache le résultat.
  """
  def fetch(key, fetch_fn, opts \\ []) when is_function(fetch_fn, 0) do
    case get(key) do
      nil ->
        case fetch_fn.() do
          {:ok, value} ->
            put(key, value, opts)
            {:ok, value}

          {:error, _reason} = error ->
            error
        end

      cached_value ->
        {:ok, cached_value}
    end
  end

  @doc """
  Supprime une valeur du cache.
  """
  def delete(key) do
    case Cachex.del(@cache_name, key) do
      {:ok, _deleted_count} -> :ok
      {:error, reason} ->
        Logger.error("Cache delete error for key #{key}: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Vide complètement le cache.
  """
  def clear do
    case Cachex.clear(@cache_name) do
      {:ok, cleared_count} ->
        Logger.info("Cleared #{cleared_count} items from cache")
        :ok
      {:error, reason} ->
        Logger.error("Cache clear error: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Retourne les statistiques du cache.
  """
  def stats do
    case Cachex.stats(@cache_name) do
      {:ok, stats} -> stats
      {:error, reason} ->
        Logger.error("Cache stats error: #{inspect(reason)}")
        %{}
    end
  end

  # Fonctions pour générer des clés de cache standardisées

  @doc """
  Génère une clé de cache pour les albums d'un artiste.
  """
  def artist_albums_key(artist_name) do
    normalized_name = normalize_artist_name(artist_name)
    "artist_albums:#{normalized_name}"
  end

  @doc """
  Génère une clé de cache pour la recherche d'un artiste.
  """
  def artist_search_key(artist_name) do
    normalized_name = normalize_artist_name(artist_name)
    "artist_search:#{normalized_name}"
  end

  @doc """
  Met en cache les albums d'un artiste avec le TTL approprié.
  """
  def cache_artist_albums(artist_name, albums) do
    key = artist_albums_key(artist_name)
    put(key, albums, ttl: @artist_albums_ttl)
  end

  @doc """
  Récupère les albums en cache d'un artiste.
  """
  def get_artist_albums(artist_name) do
    key = artist_albums_key(artist_name)
    get(key)
  end

  @doc """
  Met en cache les résultats de recherche d'un artiste.
  """
  def cache_artist_search(artist_name, search_results) do
    key = artist_search_key(artist_name)
    put(key, search_results, ttl: @artist_search_ttl)
  end

  @doc """
  Récupère les résultats de recherche en cache d'un artiste.
  """
  def get_artist_search(artist_name) do
    key = artist_search_key(artist_name)
    get(key)
  end

  # Fonctions utilitaires privées

  defp normalize_artist_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^a-z0-9\s]/, "") # Supprimer la ponctuation
    |> String.replace(~r/\s+/, "_")        # Remplacer espaces par underscores
    |> String.replace(~r/^the_/, "")       # Supprimer "the_" au début
  end

  defp normalize_artist_name(_), do: "unknown"
end
