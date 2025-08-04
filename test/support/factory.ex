defmodule SpotifyApi.Factory do
  use ExMachina.Ecto, repo: SpotifyApi.Repo

  def artist_factory do
    artist = %SpotifyApi.Schemas.Artist{
      spotify_id: sequence(:spotify_id, &"spotify_artist_#{&1}"),
      name: sequence(:name, &"Artist #{&1}")
    }
    IO.inspect(artist, label: "Factory - Création artiste")
    artist
  end

  def album_factory do
    %SpotifyApi.Schemas.Album{
      spotify_id: sequence(:spotify_id, &"spotify_album_#{&1}"),
      name: sequence(:name, &"Album #{&1}"),
      album_type: "album",
      release_date: ~D[2023-01-01],
      total_tracks: 12,
      artist: build(:artist)
    }
  end
end
