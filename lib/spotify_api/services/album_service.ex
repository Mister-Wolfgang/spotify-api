defmodule SpotifyApi.Services.AlbumService do
  @moduledoc """
  Service pour gérer la persistance et la récupération des albums.
  """

  alias SpotifyApi.Repo
  alias SpotifyApi.Schemas.{Artist, Album}
  import Ecto.Query

  @doc """
  Crée ou met à jour des albums pour un artiste donné.
  """
  def create_or_update_albums_for_artist(%Artist{} = artist, spotify_albums_data) do
    Enum.reduce_while(spotify_albums_data, {:ok, []}, fn album_data, {:ok, acc} ->
      case create_or_update_album(artist, album_data) do
        {:ok, album} -> {:cont, {:ok, [album | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, albums} -> {:ok, Enum.reverse(albums)}
      error -> error
    end
  end

  @doc """
  Crée ou met à jour un album pour un artiste.
  """
  def create_or_update_album(%Artist{} = artist, spotify_album_data) do
    spotify_id = spotify_album_data["id"]

    case Repo.get_by(Album, spotify_id: spotify_id) do
      nil ->
        create_album(artist, spotify_album_data)

      existing_album ->
        update_album(existing_album, spotify_album_data)
    end
  end

  @doc """
  Crée un nouvel album.
  """
  def create_album(%Artist{} = artist, spotify_album_data) do
    attrs = build_album_attrs(artist, spotify_album_data)

    %Album{}
    |> Album.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Met à jour un album existant.
  """
  def update_album(%Album{} = album, spotify_album_data) do
    attrs = build_album_attrs(nil, spotify_album_data)

    album
    |> Album.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Récupère les albums d'un artiste par son ID Spotify.
  """
  def get_albums_by_artist_spotify_id(spotify_id) do
    query = from a in Album,
      join: artist in Artist,
      on: a.artist_id == artist.id,
      where: artist.spotify_id == ^spotify_id,
      order_by: [desc: a.release_date]

    Repo.all(query)
  end

  @doc """
  Supprime les albums d'un artiste qui ne sont plus dans la liste Spotify.
  """
  def remove_outdated_albums(%Artist{} = artist, current_spotify_ids) do
    query = from a in Album,
      where: a.artist_id == ^artist.id and a.spotify_id not in ^current_spotify_ids

    Repo.delete_all(query)
  end

  # Fonction privée pour construire les attributs d'un album
  defp build_album_attrs(%Artist{id: artist_id}, spotify_album_data) do
    build_album_attrs(artist_id, spotify_album_data)
  end

  defp build_album_attrs(artist_id, spotify_album_data) do
    release_date = parse_release_date(spotify_album_data["release_date"])

    attrs = %{
      spotify_id: spotify_album_data["id"],
      name: spotify_album_data["name"],
      album_type: spotify_album_data["album_type"],
      release_date: release_date,
      total_tracks: spotify_album_data["total_tracks"]
    }

    if artist_id, do: Map.put(attrs, :artist_id, artist_id), else: attrs
  end

  # Parse la date de sortie depuis différents formats Spotify
  defp parse_release_date(nil), do: nil
  defp parse_release_date(date_string) when is_binary(date_string) do
    case String.length(date_string) do
      4 -> Date.from_iso8601!("#{date_string}-01-01")  # Année seulement
      7 -> Date.from_iso8601!("#{date_string}-01")     # Année-mois
      10 -> Date.from_iso8601!(date_string)            # Année-mois-jour
      _ -> Date.from_iso8601!("1900-01-01")            # Fallback
    end
  rescue
    _ -> Date.from_iso8601!("1900-01-01")
  end
end
