defmodule SpotifyApi.Spotify.ArtistsTest do
  use ExUnit.Case, async: true
  import Mox

  alias SpotifyApi.Spotify.Artists

  setup :verify_on_exit!

  describe "find_best_match/2" do
    test "selects exact name match" do
      search_term = "Queen"
      candidates = [
        %{"name" => "Queen", "popularity" => 85, "id" => "1"},
        %{"name" => "Queen Tribute Band", "popularity" => 30, "id" => "2"},
        %{"name" => "The Queen", "popularity" => 40, "id" => "3"}
      ]

      assert %{"id" => "1"} = Artists.find_best_match(search_term, candidates)
    end

    test "selects most popular when no exact match" do
      search_term = "Rock Band"
      candidates = [
        %{"name" => "Rock Band Tribute", "popularity" => 30, "id" => "1"},
        %{"name" => "Ultimate Rock Band", "popularity" => 70, "id" => "2"},
        %{"name" => "Rock Band Cover", "popularity" => 45, "id" => "3"}
      ]

      assert %{"id" => "2"} = Artists.find_best_match(search_term, candidates)
    end

    test "returns nil for empty candidates" do
      assert nil == Artists.find_best_match("Any Artist", [])
    end

    test "handles candidates with missing popularity" do
      search_term = "Test"
      candidates = [
        %{"name" => "Test Band", "id" => "1"},  # Pas de popularity
        %{"name" => "Test Group", "popularity" => 50, "id" => "2"}
      ]

      # Devrait sélectionner celui avec popularity
      assert %{"id" => "2"} = Artists.find_best_match(search_term, candidates)
    end
  end

  # Note: Les tests pour search/1 et get_artist_by_id/1 sont dans les tests d'intégration
  # car ils nécessitent des appels HTTP avec des GenServers supervisés
end
