defmodule SpotifyApi.Services.ArtistServiceTest do
  use SpotifyApi.DataCase

  import SpotifyApi.Factory

  alias SpotifyApi.Services.ArtistService
  alias SpotifyApi.Schemas.Artist

  describe "find_or_create_artist/1" do
    test "creates a new artist when it doesn't exist" do
      spotify_data = %{
        "id" => "4Z8W4fKeB5YxbusRsdQVPb",
        "name" => "Radiohead"
      }

      assert {:ok, %Artist{} = artist} = ArtistService.find_or_create_artist(spotify_data)
      assert artist.spotify_id == "4Z8W4fKeB5YxbusRsdQVPb"
      assert artist.name == "Radiohead"
    end

    test "returns existing artist when it already exists" do
      spotify_data = %{
        "id" => "4Z8W4fKeB5YxbusRsdQVPb",
        "name" => "Radiohead"
      }

      # Créer l'artiste une première fois
      {:ok, first_artist} = ArtistService.find_or_create_artist(spotify_data)

      # Tenter de le créer à nouveau
      {:ok, second_artist} = ArtistService.find_or_create_artist(spotify_data)

      # Doit retourner le même artiste
      assert first_artist.id == second_artist.id
    end
  end

  describe "get_by_spotify_id/1" do
    test "returns artist when it exists" do
      artist = insert(:artist)
      result = ArtistService.get_by_spotify_id(artist.spotify_id)
      assert result.id == artist.id
    end

    test "returns nil when artist doesn't exist" do
      result = ArtistService.get_by_spotify_id("nonexistent_id")
      assert result == nil
    end
  end

  describe "get_by_spotify_id_with_albums/1" do
    test "returns artist with preloaded albums" do
      artist = insert(:artist)
      album1 = insert(:album, artist: artist)
      album2 = insert(:album, artist: artist)

      result = ArtistService.get_by_spotify_id_with_albums(artist.spotify_id)

      assert result.id == artist.id
      assert length(result.albums) == 2
      assert Enum.any?(result.albums, &(&1.id == album1.id))
      assert Enum.any?(result.albums, &(&1.id == album2.id))
    end
  end
end
