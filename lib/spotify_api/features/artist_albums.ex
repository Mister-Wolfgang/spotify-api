defmodule SpotifyApi.Features.ArtistAlbums do
  @moduledoc """
  Feature principale pour récupérer les albums d'un artiste.
  Orchestre la recherche d'artiste et la récupération d'albums.
  """

  alias SpotifyApi.Spotify.{Artists, Albums}
  alias SpotifyApi.Services.{ArtistService, AlbumService}

  require Logger

  @doc """
  Point d'entrée principal pour récupérer les albums d'un artiste.

  1. Recherche l'artiste par nom
  2. Trouve le meilleur match
  3. Récupère ses albums
  4. Les trie par date
  """
  def get_albums(artist_name, opts \\ []) when is_binary(artist_name) do
    Logger.info("🎵 DEBUT: Getting albums for artist: #{artist_name}")

    # Pour le debug, forcer bypass du cache si demandé
    search_opts = if Keyword.get(opts, :bypass_cache, false), do: [bypass_cache: true], else: []

    with {:ok, artists} <- Artists.search(artist_name, search_opts),
         {:ok, artist} <- find_target_artist(artists, artist_name),
         {:ok, albums} <- Albums.get_artist_albums(artist["id"], opts),
         {:ok, saved_artist} <- save_artist_and_albums(artist, albums) do

      Logger.info("🎵 SUCCÈS: Successfully retrieved and saved #{length(albums)} albums for #{artist_name}")
      {:ok, %{"artist" => saved_artist.name, "albums" => albums}}
    else
      {:error, :no_artists_found} ->
        Logger.warning("🎵 ERREUR: No artists found for: #{artist_name}")
        {:error, :artist_not_found}

      {:error, :no_albums_found} ->
        Logger.info("🎵 INFO: No albums found for artist: #{artist_name}")
        {:error, :no_albums_found}

      {:error, reason} ->
        Logger.error("🎵 ERREUR: Failed to get albums for #{artist_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end


  # Fonctions privées

  defp find_target_artist([], _artist_name) do
    {:error, :no_artists_found}
  end

  defp find_target_artist(artists, artist_name) when is_list(artists) do
    Logger.info("🎯 MATCHING: Recherche du meilleur match pour '#{artist_name}' parmi #{length(artists)} candidats")

    case Artists.find_best_match(artist_name, artists) do
      nil ->
        Logger.warning("🎯 ÉCHEC: Aucun match trouvé pour '#{artist_name}'")
        {:error, :no_artists_found}

      artist ->
        Logger.info("🎯 MATCH TROUVÉ: '#{artist["name"]}' (ID: #{artist["id"]}) pour '#{artist_name}'")
        {:ok, artist}
    end
  end

  # Fonction privée pour sauvegarder l'artiste et ses albums en base de données
  defp save_artist_and_albums(spotify_artist_data, spotify_albums_data) do
    Logger.info("💾 SAUVEGARDE: Sauvegarde de l'artiste #{spotify_artist_data["name"]} et ses #{length(spotify_albums_data)} albums")

    with {:ok, artist} <- ArtistService.find_or_create_artist(spotify_artist_data),
         {:ok, _albums} <- AlbumService.create_or_update_albums_for_artist(artist, spotify_albums_data) do
      
      Logger.info("💾 SUCCÈS: Artiste et albums sauvegardés avec succès")
      {:ok, artist}
    else
      {:error, reason} ->
        Logger.error("💾 ERREUR: Échec de la sauvegarde: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
