defmodule SpotifyApiWeb.AlbumWebController do
  use SpotifyApiWeb, :controller

  def index(conn, params) do
    artist = Map.get(params, "artist", "")
    {artist_name, albums} =
      if artist != "" do
        case SpotifyApi.Features.ArtistAlbums.get_albums(artist, []) do
          {:ok, %{"artist" => found_artist_name, "albums" => albums_list}} ->
            {found_artist_name, albums_list}

          _ ->
            {artist, []}
        end
      else
        {"", []}
      end
    render(conn, "index.html", artist: artist_name, albums: albums)
  end
end
