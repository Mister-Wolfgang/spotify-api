defmodule SpotifyApi.Spotify.AlbumsTest do
  use ExUnit.Case, async: true
  import Mox

  alias SpotifyApi.Spotify.Albums

  setup :verify_on_exit!

  setup do
    # Démarrer les services nécessaires pour les tests
    rate_limiter = start_supervised!({SpotifyApi.RateLimiter, [requests_per_second: 100, burst_size: 100, name: nil]})
    auth_manager = start_supervised!({SpotifyApi.Spotify.AuthManager, [name: nil]})

    # Permettre aux processus d'utiliser les mocks
    Mox.allow(Tesla.MockAdapter, self(), rate_limiter)
    Mox.allow(Tesla.MockAdapter, self(), auth_manager)

    # Vider le cache pour éviter les interférences entre tests
    SpotifyApi.Cache.clear()

    {:ok, rate_limiter: rate_limiter, auth_manager: auth_manager}
  end

  describe "get_artist_albums/1" do
    test "retrieves and sorts albums by release date", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "test_artist_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      mock_albums_response(artist_id, [
        %{
          "id" => "album3",
          "name" => "Latest Album",
          "release_date" => "2023-06-15",
          "release_date_precision" => "day",
          "album_type" => "album"
        },
        %{
          "id" => "album1",
          "name" => "First Album",
          "release_date" => "2020-01-01",
          "release_date_precision" => "day",
          "album_type" => "album"
        },
        %{
          "id" => "album2",
          "name" => "Second Album",
          "release_date" => "2021-12-25",
          "release_date_precision" => "day",
          "album_type" => "album"
        }
      ])

      assert {:ok, albums} = Albums.get_artist_albums(artist_id, opts)
      assert length(albums) == 3

      # Vérifier que c'est trié par date (plus récent en premier)
      dates = Enum.map(albums, & &1["release_date"])
      assert dates == ["2023-06-15", "2021-12-25", "2020-01-01"]
    end

    test "handles different release date precisions", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "test_artist_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      mock_albums_response(artist_id, [
        %{
          "id" => "album1",
          "name" => "Year Only Album",
          "release_date" => "2020",
          "release_date_precision" => "year",
          "album_type" => "album"
        },
        %{
          "id" => "album2",
          "name" => "Month Precision Album",
          "release_date" => "2020-06",
          "release_date_precision" => "month",
          "album_type" => "album"
        },
        %{
          "id" => "album3",
          "name" => "Day Precision Album",
          "release_date" => "2020-06-15",
          "release_date_precision" => "day",
          "album_type" => "album"
        }
      ])

      assert {:ok, albums} = Albums.get_artist_albums(artist_id, opts)

      # Tous devraient avoir une date normalisée pour le tri
      release_dates = Enum.map(albums, & &1["normalized_release_date"])
      assert Enum.all?(release_dates, &is_binary/1)
      assert Enum.all?(release_dates, &String.match?(&1, ~r/\d{4}-\d{2}-\d{2}/))
    end

    test "handles pagination correctly", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "test_artist_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager, limit: 50]

      # Mock première page (50 albums avec next_url)
      mock_albums_pagination_response(artist_id, 0, create_test_albums(1, 50), 100)

      assert {:ok, albums} = Albums.get_artist_albums(artist_id, opts)
      assert length(albums) == 50

      # Vérifier que tous les albums sont présents
      album_names = Enum.map(albums, & &1["name"])
      assert "Album 1" in album_names
      assert "Album 50" in album_names
    end

    test "filters out duplicates", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "test_artist_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      mock_albums_response(artist_id, [
        %{
          "id" => "album1",
          "name" => "Same Album",
          "release_date" => "2020-01-01",
          "album_type" => "album"
        },
        %{
          "id" => "album1",  # Même ID = doublon
          "name" => "Same Album",
          "release_date" => "2020-01-01",
          "album_type" => "album"
        },
        %{
          "id" => "album2",
          "name" => "Different Album",
          "release_date" => "2020-02-01",
          "album_type" => "album"
        }
      ])

      assert {:ok, albums} = Albums.get_artist_albums(artist_id, opts)
      assert length(albums) == 2

      # Vérifier que les deux albums sont présents (ordre peut varier après tri)
      album_ids = Enum.map(albums, & &1["id"]) |> Enum.sort()
      assert album_ids == ["album1", "album2"]
    end

    test "filters by album type", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "test_artist_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      # Mock unifié pour tous les appels - 3 appels attendus (2 auth + 1 get, le 2e get utilise le cache)
      expect(Tesla.MockAdapter, :call, 3, fn
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
          cond do
            String.contains?(url, "/artists/#{artist_id}/albums") and String.contains?(url, "include_groups=album%2Csingle%2Ccompilation") ->
              # Premier appel - tous les types
              {:ok, %Tesla.Env{
                status: 200,
                body: %{
                  "items" => [
                    %{
                      "id" => "album1",
                      "name" => "Studio Album",
                      "release_date" => "2020-01-01",
                      "album_type" => "album"
                    },
                    %{
                      "id" => "single1",
                      "name" => "Hit Single",
                      "release_date" => "2020-02-01",
                      "album_type" => "single"
                    },
                    %{
                      "id" => "comp1",
                      "name" => "Best Of",
                      "release_date" => "2020-03-01",
                      "album_type" => "compilation"
                    }
                  ],
                  "total" => 3,
                  "limit" => 50,
                  "offset" => 0,
                  "next" => nil
                }
              }}
            String.contains?(url, "/artists/#{artist_id}/albums") and String.contains?(url, "include_groups=album") ->
              # Deuxième appel - seulement albums
              {:ok, %Tesla.Env{
                status: 200,
                body: %{
                  "items" => [
                    %{
                      "id" => "album1",
                      "name" => "Studio Album",
                      "release_date" => "2020-01-01",
                      "album_type" => "album"
                    }
                  ],
                  "total" => 1,
                  "limit" => 50,
                  "offset" => 0,
                  "next" => nil
                }
              }}
            true ->
              {:ok, %Tesla.Env{status: 404, body: %{"error" => "Not found"}}}
          end
      end)

      # Par défaut, inclure tous les types
      assert {:ok, all_albums} = Albums.get_artist_albums(artist_id, opts)
      assert length(all_albums) == 3

      # Filtrer seulement les albums (différente clé de cache)
      assert {:ok, albums_only} = Albums.get_artist_albums(artist_id, opts ++ [album_types: ["album"]])
      assert length(albums_only) == 1
      assert List.first(albums_only)["album_type"] == "album"
    end

    test "handles API errors", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "non_existent_artist"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      mock_albums_error_response()

      assert {:error, _reason} = Albums.get_artist_albums(artist_id, opts)
    end

    test "uses cache for subsequent requests", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      artist_id = "cached_artist_id"
      opts = [rate_limiter: rate_limiter, auth_manager: auth_manager]

      # Premier appel - mock HTTP
      mock_albums_response(artist_id, [
        %{
          "id" => "album1",
          "name" => "Cached Album",
          "release_date" => "2020-01-01",
          "album_type" => "album"
        }
      ])

      assert {:ok, albums1} = Albums.get_artist_albums(artist_id, opts)

      # Deuxième appel - devrait utiliser le cache
      assert {:ok, albums2} = Albums.get_artist_albums(artist_id, opts)

      assert albums1 == albums2
    end
  end

  describe "normalize_album_data/1" do
    test "adds normalized release date" do
      album = %{
        "id" => "test",
        "name" => "Test Album",
        "release_date" => "2020-06-15",
        "release_date_precision" => "day"
      }

      normalized = Albums.normalize_album_data(album)
      assert normalized["normalized_release_date"] == "2020-06-15"
    end

    test "normalizes year-only dates" do
      album = %{
        "id" => "test",
        "name" => "Test Album",
        "release_date" => "2020",
        "release_date_precision" => "year"
      }

      normalized = Albums.normalize_album_data(album)
      assert normalized["normalized_release_date"] == "2020-01-01"
    end

    test "normalizes month-only dates" do
      album = %{
        "id" => "test",
        "name" => "Test Album",
        "release_date" => "2020-06",
        "release_date_precision" => "month"
      }

      normalized = Albums.normalize_album_data(album)
      assert normalized["normalized_release_date"] == "2020-06-01"
    end

    test "handles missing release date" do
      album = %{
        "id" => "test",
        "name" => "Test Album"
      }

      normalized = Albums.normalize_album_data(album)
      assert normalized["normalized_release_date"] == "1900-01-01"
    end
  end

  # Helper functions
  defp mock_albums_response(artist_id, albums) do
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
              "items" => albums,
              "total" => length(albums),
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

  defp mock_albums_pagination_response(artist_id, offset, albums, total) do
    next_url = if offset + length(albums) < total do
      "https://api.spotify.com/v1/artists/#{artist_id}/albums?offset=#{offset + length(albums)}"
    else
      nil
    end

    # Mock unifié pour authentification et albums avec pagination
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
        cond do
          String.contains?(url, "/artists/#{artist_id}/albums") and String.contains?(url, "offset=#{offset}") ->
            {:ok, %Tesla.Env{
              status: 200,
              body: %{
                "items" => albums,
                "total" => total,
                "limit" => length(albums),
                "offset" => offset,
                "next" => next_url
              }
            }}
          String.contains?(url, "/artists/#{artist_id}/albums") ->
            # Fallback pour autres offsets
            {:ok, %Tesla.Env{
              status: 200,
              body: %{
                "items" => [],
                "total" => total,
                "limit" => 50,
                "offset" => 999,
                "next" => nil
              }
            }}
          true ->
            {:ok, %Tesla.Env{status: 404, body: %{"error" => "Not found"}}}
        end
    end)
  end

  defp mock_albums_error_response do
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

    # Mock pour l'erreur
    expect(Tesla.MockAdapter, :call, fn
      %Tesla.Env{method: :get}, _opts ->
        {:ok, %Tesla.Env{
          status: 404,
          body: %{"error" => %{"status" => 404, "message" => "Not found"}}
        }}
    end)
  end

  defp create_test_albums(start_num, end_num) do
    for i <- start_num..end_num do
      # Générer des dates valides au format ISO
      year = 2020 + rem(i, 4)
      month = String.pad_leading("#{rem(i, 12) + 1}", 2, "0")
      day = String.pad_leading("#{rem(i, 28) + 1}", 2, "0")

      %{
        "id" => "album#{i}",
        "name" => "Album #{i}",
        "release_date" => "#{year}-#{month}-#{day}",
        "release_date_precision" => "day",
        "album_type" => "album"
      }
    end
  end
end
