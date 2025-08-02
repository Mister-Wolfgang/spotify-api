defmodule SpotifyApi.Integration.ArtistSearchIntegrationTest do
  use ExUnit.Case, async: false  # Pas async car on teste le cache partagé

  alias SpotifyApi.Spotify.Artists
  alias SpotifyApi.Cache

  import Mox

  setup do
    # Démarrer les services nécessaires pour les tests d'intégration
    rate_limiter = start_supervised!({SpotifyApi.RateLimiter, [requests_per_second: 100, burst_size: 100, name: nil]})
    auth_manager = start_supervised!({SpotifyApi.Spotify.AuthManager, [name: nil]})

    # Permettre aux processus d'utiliser les mocks
    Mox.allow(Tesla.MockAdapter, self(), rate_limiter)
    Mox.allow(Tesla.MockAdapter, self(), auth_manager)

    # Nettoyer le cache avant chaque test
    Cache.clear()

    {:ok, rate_limiter: rate_limiter, auth_manager: auth_manager}
  end

  describe "artist search integration" do
    @describetag :integration
    test "complete flow: search -> cache -> reuse", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_name = "Integration Test Artist"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      # Mock première recherche
      mock_artist_search_response(artist_name)

      # Première recherche - devrait appeler l'API
      assert {:ok, artists1} = Artists.search(artist_name, opts)
      assert length(artists1) == 1
      assert List.first(artists1)["name"] == artist_name

      # Vérifier que c'est en cache
      cached_result = Cache.get_artist_search(artist_name)
      assert cached_result == artists1

      # Deuxième recherche - devrait utiliser le cache
      # (pas de nouveau mock configuré, donc échouerait si l'API était appelée)
      assert {:ok, artists2} = Artists.search(artist_name, opts)
      assert artists1 == artists2
    end

    test "handles search with normalization and caching", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      _base_name = "Test Artist"
      variants = [
        "test artist",
        "Test Artist",
        "TEST ARTIST",
        " Test Artist ",
        "The Test Artist"
      ]

      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      # Mock pour le nom normalisé
      mock_artist_search_response("test artist")

      # Première recherche avec une variante
      {:ok, artists1} = Artists.search(List.first(variants), opts)

      # Toutes les autres variantes devraient utiliser le cache
      for variant <- Enum.drop(variants, 1) do
        {:ok, artists} = Artists.search(variant, opts)
        assert artists == artists1
      end
    end
  end

  defp mock_artist_search_response(artist_name) do
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
        assert String.contains?(url, "/search")

        {:ok, %Tesla.Env{
          status: 200,
          body: %{
            "artists" => %{
              "items" => [
                %{
                  "id" => "test_id_123",
                  "name" => artist_name,
                  "popularity" => 75,
                  "followers" => %{"total" => 100_000}
                }
              ],
              "total" => 1
            }
          }
        }}
    end)
  end
end
