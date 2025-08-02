defmodule SpotifyApi.Integration.AlbumsIntegrationTest do
  use ExUnit.Case, async: false

  alias SpotifyApi.Spotify.{Artists, Albums}
  alias SpotifyApi.Cache

  import Mox

  setup do
    # Démarrer les services nécessaires pour les tests d'intégration
    rate_limiter = start_supervised!({SpotifyApi.RateLimiter, [requests_per_second: 100, burst_size: 100, name: nil]})
    auth_manager = start_supervised!({SpotifyApi.Spotify.AuthManager, [name: nil]})

    # Permettre aux processus d'utiliser les mocks
    Mox.allow(Tesla.MockAdapter, self(), rate_limiter)
    Mox.allow(Tesla.MockAdapter, self(), auth_manager)

    Cache.clear()
    {:ok, rate_limiter: rate_limiter, auth_manager: auth_manager}
  end

  describe "complete albums flow" do
    @describetag :integration

    test "search artist -> get albums -> cache -> format", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_name = "Test Integration Artist"
      artist_id = "integration_test_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      # Mock recherche d'artiste
      mock_artist_search(artist_name, artist_id)

      # Mock récupération d'albums
      mock_artist_albums(artist_id)

      # 1. Rechercher l'artiste
      {:ok, artists} = Artists.search(artist_name, opts)
      artist = Artists.find_best_match(artist_name, artists)
      assert artist["id"] == artist_id

      # 2. Récupérer ses albums
      {:ok, albums} = Albums.get_artist_albums(artist_id, opts)
      assert length(albums) == 3

      # 3. Vérifier le tri par date
      dates = Enum.map(albums, & &1["normalized_release_date"])
      assert dates == ["2023-01-01", "2022-01-01", "2021-01-01"]

      # 4. Vérifier le cache
      cached_albums = Cache.get("artist_albums:#{artist_id}:album,compilation,single")
      assert cached_albums == albums
    end
  end

  defp mock_artist_search(artist_name, artist_id) do
    # Mock pour l'authentification
    expect(Tesla.MockAdapter, :call, fn
      %Tesla.Env{method: :post, url: url}, _opts ->
        if String.contains?(url, "token") do
          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "access_token" => "mock_token",
              "token_type" => "Bearer",
              "expires_in" => 3600
            }
          }}
        end
    end)

    # Mock pour la recherche d'artistes
    expect(Tesla.MockAdapter, :call, fn
      %Tesla.Env{method: :get, url: url}, _opts ->
        if String.contains?(url, "/search") do
          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "artists" => %{
                "items" => [
                  %{
                    "id" => artist_id,
                    "name" => artist_name,
                    "popularity" => 80
                  }
                ]
              }
            }
          }}
        end
    end)
  end

  defp mock_artist_albums(artist_id) do
    # Mock unifié pour authentification et albums
    expect(Tesla.MockAdapter, :call, 2, fn
      %Tesla.Env{method: :post, url: url}, _opts ->
        if String.contains?(url, "token") do
          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "access_token" => "mock_token",
              "token_type" => "Bearer",
              "expires_in" => 3600
            }
          }}
        else
          {:ok, %Tesla.Env{status: 404, body: %{"error" => "Not found"}}}
        end

      %Tesla.Env{method: :get, url: url}, _opts ->
        if String.contains?(url, "/artists/#{artist_id}/albums") do
          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "items" => [
                %{
                  "id" => "album1",
                  "name" => "Latest Album",
                  "release_date" => "2023-01-01",
                  "release_date_precision" => "day",
                  "album_type" => "album",
                  "total_tracks" => 12
                },
                %{
                  "id" => "album2",
                  "name" => "Middle Album",
                  "release_date" => "2022-01-01",
                  "release_date_precision" => "day",
                  "album_type" => "album",
                  "total_tracks" => 10
                },
                %{
                  "id" => "album3",
                  "name" => "First Album",
                  "release_date" => "2021-01-01",
                  "release_date_precision" => "day",
                  "album_type" => "album",
                  "total_tracks" => 15
                }
              ],
              "total" => 3,
              "limit" => 50,
              "offset" => 0,
              "next" => nil
            }
          }}
        else
          {:ok, %Tesla.Env{status: 404, body: %{"error" => "Not found"}}}
        end
    end)
  end
end
