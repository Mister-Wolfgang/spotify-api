defmodule SpotifyApi.Services.ArtistService do
  @moduledoc """
  Service pour gérer la persistance et la récupération des artistes.
  """

  alias SpotifyApi.Repo
  alias SpotifyApi.Schemas.Artist
  import Ecto.Query

  @doc """
  Trouve ou crée un artiste basé sur les données Spotify.
  """
  def find_or_create_artist(spotify_artist_data) do
    spotify_id = spotify_artist_data["id"]
    name = spotify_artist_data["name"]

    changeset =
      Artist.changeset(%Artist{}, %{
        spotify_id: spotify_id,
        name: name
      })
      |> Ecto.Changeset.unique_constraint(:spotify_id, name: "artists_spotify_id_index")

    case Repo.insert(changeset, on_conflict: [set: [name: name]], conflict_target: :spotify_id, returning: true) do
      {:ok, artist} -> {:ok, artist}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Crée un nouvel artiste.
  """
  def create_artist(attrs) do
    %Artist{}
    |> Artist.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Met à jour un artiste existant.
  """
  def update_artist(%Artist{} = artist, attrs) do
    artist
    |> Artist.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Récupère un artiste par son ID Spotify.
  """
  def get_by_spotify_id(spotify_id) do
    Repo.get_by(Artist, spotify_id: spotify_id)
  end

  @doc """
  Récupère un artiste avec ses albums.
  """
  def get_artist_with_albums(artist_id) do
    Artist
    |> where([a], a.id == ^artist_id)
    |> preload([:albums])
    |> Repo.one()
  end

  @doc """
  Récupère un artiste par son ID Spotify avec ses albums.
  """
  def get_by_spotify_id_with_albums(spotify_id) do
    Artist
    |> where([a], a.spotify_id == ^spotify_id)
    |> preload([:albums])
    |> Repo.one()
  end
end
