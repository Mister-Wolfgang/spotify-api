defmodule SpotifyApi.CacheTest do
  use ExUnit.Case, async: true

  alias SpotifyApi.Cache

  setup do
    # Nettoyer le cache avant chaque test
    Cachex.clear(:spotify_cache)
    :ok
  end

  describe "get/2" do
    test "returns nil for non-existent key" do
      assert Cache.get("non_existent") == nil
    end

    test "returns cached value" do
      key = "test_key"
      value = %{"artist" => "test"}

      Cache.put(key, value)

      assert Cache.get(key) == value
    end

    test "returns nil for expired cache entry" do
      key = "expiring_key"
      value = %{"data" => "test"}

      # Cache avec TTL un peu plus long pour fiabilité
      Cache.put(key, value, ttl: 200)

      # Vérifier que c'est bien en cache
      assert Cache.get(key) == value

      # Attendre expiration
      :timer.sleep(250)

      assert Cache.get(key) == nil
    end
  end

  describe "put/3" do
    test "stores value in cache" do
      key = "store_test"
      value = %{"albums" => []}

      assert :ok = Cache.put(key, value)
      assert Cache.get(key) == value
    end

    test "overwrites existing value" do
      key = "overwrite_test"
      value1 = %{"count" => 1}
      value2 = %{"count" => 2}

      Cache.put(key, value1, ttl: 1000)
      assert Cache.get(key) == value1

      Cache.put(key, value2, ttl: 1000)
      assert Cache.get(key) == value2
    end

    test "respects custom TTL" do
      key = "ttl_test"
      value = %{"temporary" => true}

      Cache.put(key, value, ttl: 200)

      assert Cache.get(key) == value

      :timer.sleep(250)

      assert Cache.get(key) == nil
    end
  end

  describe "fetch/3" do
    test "returns cached value if exists" do
      key = "fetch_cached"
      cached_value = %{"cached" => true}

      Cache.put(key, cached_value, ttl: 1000)

      # La fonction ne devrait pas être appelée
      fetch_fn = fn ->
        flunk("Fetch function should not be called when value is cached")
      end

      assert Cache.fetch(key, fetch_fn) == {:ok, cached_value}
    end

    test "calls fetch function and caches result when not cached" do
      key = "fetch_new"
      new_value = %{"fetched" => true}

      fetch_fn = fn -> {:ok, new_value} end

      assert Cache.fetch(key, fetch_fn) == {:ok, new_value}

      # Vérifier que c'est maintenant en cache
      assert Cache.get(key) == new_value
    end

    test "handles fetch function errors" do
      key = "fetch_error"

      fetch_fn = fn -> {:error, :fetch_failed} end

      assert Cache.fetch(key, fetch_fn) == {:error, :fetch_failed}

      # Ne devrait pas cacher les erreurs
      assert Cache.get(key) == nil
    end

    test "supports custom TTL in fetch" do
      key = "fetch_ttl"
      value = %{"ttl_test" => true}

      fetch_fn = fn -> {:ok, value} end

      assert Cache.fetch(key, fetch_fn, ttl: 100) == {:ok, value}

      :timer.sleep(150)

      assert Cache.get(key) == nil
    end
  end

  describe "delete/1" do
    test "removes value from cache" do
      key = "delete_test"
      value = %{"to_delete" => true}

      Cache.put(key, value)
      assert Cache.get(key) == value

      assert :ok = Cache.delete(key)
      assert Cache.get(key) == nil
    end

    test "handles deletion of non-existent key" do
      assert :ok = Cache.delete("non_existent")
    end
  end

  describe "cache key generation" do
    test "generates consistent keys for artist albums" do
      artist_name = "Pink Floyd"
      key1 = Cache.artist_albums_key(artist_name)
      key2 = Cache.artist_albums_key(artist_name)

      assert key1 == key2
      assert String.contains?(key1, "artist_albums")
      assert String.contains?(key1, "pink_floyd")
    end

    test "generates different keys for different artists" do
      key1 = Cache.artist_albums_key("Beatles")
      key2 = Cache.artist_albums_key("Rolling Stones")

      assert key1 != key2
    end

    test "normalizes artist names in keys" do
      key1 = Cache.artist_albums_key("The Beatles")
      key2 = Cache.artist_albums_key("the beatles")
      key3 = Cache.artist_albums_key("THE BEATLES")

      # Tous devraient être identiques après normalisation
      assert key1 == key2
      assert key2 == key3
    end
  end
end
