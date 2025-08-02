defmodule SpotifyApi.Spotify.Albums do
  @moduledoc """
  Module pour la récupération des albums d'un artiste depuis l'API Spotify.
  Gère la pagination, le tri par date et la mise en cache.
  """

  alias SpotifyApi.Spotify.HttpClient
  alias SpotifyApi.Cache

  require Logger

  @default_album_types ["album", "single", "compilation"]
  @albums_per_page 50
  @max_albums 500  # Limite pour éviter les boucles infinies

  @doc """
  Récupère tous les albums d'un artiste, triés par date de sortie (plus récent en premier).

  Options:
  - album_types: Liste des types d'albums à inclure (défaut: tous)
  - limit: Nombre maximum d'albums à récupérer
  """
  def get_artist_albums(artist_id, opts \\ []) when is_binary(artist_id) do
    album_types = Keyword.get(opts, :album_types, @default_album_types)
    limit = Keyword.get(opts, :limit, @max_albums)
    http_opts = Keyword.take(opts, [:rate_limiter, :auth_manager])

    cache_key = build_cache_key(artist_id, album_types)

    Cache.fetch(
      cache_key,
      fn -> fetch_all_albums_from_spotify(artist_id, album_types, limit, http_opts) end,
      ttl: :timer.hours(6)
    )
  end

  @doc """
  Normalise les données d'un album pour avoir un format cohérent.
  Ajoute une date de sortie normalisée pour le tri.
  """
  def normalize_album_data(album) when is_map(album) do
    normalized_date = normalize_release_date(
      Map.get(album, "release_date"),
      Map.get(album, "release_date_precision", "day")
    )

    album
    |> Map.put("normalized_release_date", normalized_date)
    |> ensure_required_fields()
  end

  @doc """
  Trie une liste d'albums par date de sortie (plus récent en premier).
  """
  def sort_albums_by_date(albums) when is_list(albums) do
    albums
    |> Enum.map(&normalize_album_data/1)
    |> Enum.sort_by(fn album ->
      Date.from_iso8601!(album["normalized_release_date"])
    end, {:desc, Date})
  end

  # Fonctions privées

  defp fetch_all_albums_from_spotify(artist_id, album_types, limit, http_opts) do
    Logger.info("Fetching albums for artist #{artist_id}")

    case fetch_albums_with_pagination(artist_id, album_types, 0, [], limit, http_opts) do
      {:ok, albums} ->
        processed_albums =
          albums
          |> remove_duplicates()
          |> sort_albums_by_date()
          |> Enum.take(limit)

        Logger.info("Retrieved #{length(processed_albums)} albums for artist #{artist_id}")
        {:ok, processed_albums}

      {:error, reason} ->
        Logger.error("Failed to fetch albums for artist #{artist_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_albums_with_pagination(artist_id, album_types, offset, accumulated_albums, remaining_limit, http_opts) do
    if remaining_limit <= 0 do
      {:ok, accumulated_albums}
    else
      batch_size = min(@albums_per_page, remaining_limit)

      case fetch_albums_batch(artist_id, album_types, offset, batch_size, http_opts) do
        {:ok, %{"items" => items, "next" => next_url}} ->
          new_accumulated = accumulated_albums ++ items

          if next_url && length(items) > 0 do
            # Continue pagination
            new_offset = offset + length(items)
            new_remaining = remaining_limit - length(items)
            fetch_albums_with_pagination(artist_id, album_types, new_offset, new_accumulated, new_remaining, http_opts)
          else
            # Fin de pagination
            {:ok, new_accumulated}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_albums_batch(artist_id, album_types, offset, limit, http_opts) do
    query_params = %{
      include_groups: Enum.join(album_types, ","),
      market: "US",  # Marché pour filtrer la disponibilité
      limit: limit,
      offset: offset
    }

    path = "/artists/#{artist_id}/albums?" <> URI.encode_query(query_params)

    case HttpClient.get(path, http_opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, {:http_error, 404, _}} ->
        Logger.warning("Artist not found: #{artist_id}")
        {:error, :artist_not_found}

      {:error, reason} ->
        Logger.error("Failed to fetch albums batch: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp remove_duplicates(albums) do
    albums
    |> Enum.uniq_by(& &1["id"])
  end

  defp normalize_release_date(nil, _precision), do: "1900-01-01"
  defp normalize_release_date("", _precision), do: "1900-01-01"
  defp normalize_release_date(date, precision) do
    case precision do
      "year" ->
        date <> "-01-01"

      "month" ->
        date <> "-01"

      "day" ->
        date

      _ ->
        # Fallback pour precision inconnue
        if String.match?(date, ~r/^\d{4}-\d{2}-\d{2}$/) do
          date
        else
          date <> "-01-01"
        end
    end
  end

  defp ensure_required_fields(album) do
    album
    |> Map.put_new("album_type", "unknown")
    |> Map.put_new("release_date", "1900-01-01")
    |> Map.put_new("name", "Unknown Album")
  end

  defp build_cache_key(artist_id, album_types) do
    types_string = album_types |> Enum.sort() |> Enum.join(",")
    "artist_albums:#{artist_id}:#{types_string}"
  end
end
