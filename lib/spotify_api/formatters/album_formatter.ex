defmodule SpotifyApi.Formatters.AlbumFormatter do
  @moduledoc """
  Module pour formater les données d'albums pour les réponses API.
  """

  @doc """
  Formate une liste d'albums pour la réponse API.
  """
  def format_albums_response(albums, artist_name) when is_list(albums) do
    %{
      artist: artist_name,
      total_albums: length(albums),
      albums: Enum.map(albums, &format_single_album/1)
    }
  end

  @doc """
  Formate un album individuel pour la réponse.
  """
  def format_single_album(album) when is_map(album) do
    %{
      id: album["id"],
      name: album["name"],
      release_date: album["release_date"],
      album_type: album["album_type"],
      total_tracks: album["total_tracks"],
      images: format_images(album["images"]),
      external_urls: album["external_urls"]
    }
  end

  @doc """
  Formate les réponses d'erreur.
  """
  def format_error_response(:artist_not_found, artist_name) do
    %{
      error: "artist_not_found",
      message: "Artist '#{artist_name}' not found",
      artist: artist_name
    }
  end

  def format_error_response(:no_albums_found, artist_name) do
    %{
      error: "no_albums_found",
      message: "No albums found for artist '#{artist_name}'",
      artist: artist_name,
      albums: []
    }
  end

  def format_error_response(reason, artist_name) do
    %{
      error: "api_error",
      message: "Failed to retrieve albums for '#{artist_name}'",
      reason: inspect(reason),
      artist: artist_name
    }
  end

  # Fonctions privées

  defp format_images(nil), do: []
  defp format_images(images) when is_list(images) do
    images
    |> Enum.map(fn image ->
      %{
        url: image["url"],
        height: image["height"],
        width: image["width"]
      }
    end)
    |> Enum.sort_by(& &1[:height], :desc)  # Plus grande image en premier
  end

  defp format_images(_), do: []
end
