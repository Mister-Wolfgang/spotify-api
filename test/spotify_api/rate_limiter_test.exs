defmodule SpotifyApi.RateLimiterTest do
  use ExUnit.Case, async: true

  alias SpotifyApi.RateLimiter

  setup do
    # Démarrer un processus sans nom pour éviter les conflits
    {:ok, pid} = RateLimiter.start_link([requests_per_second: 10, burst_size: 10, name: nil])

    # Nettoyer à la fin du test
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    {:ok, rate_limiter: pid}
  end

  describe "acquire/1" do
    test "allows request when tokens are available", %{rate_limiter: pid} do
      assert :ok = RateLimiter.acquire(pid)
    end

    test "blocks when no tokens available" do
      # Configuration spécifique pour ce test
      {:ok, pid} = RateLimiter.start_link([requests_per_second: 1, burst_size: 1, name: nil])

      # Nettoyer à la fin du test
      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      # Premier appel OK
      assert :ok = RateLimiter.acquire(pid)

      # Deuxième appel immédiat devrait être bloqué
      start_time = System.monotonic_time(:millisecond)
      assert :ok = RateLimiter.acquire(pid)
      end_time = System.monotonic_time(:millisecond)

      # Devrait avoir attendu au moins 900ms (proche de 1 seconde)
      assert (end_time - start_time) >= 900
    end

    test "refills tokens over time" do
      # Configuration spécifique pour ce test
      {:ok, pid} = RateLimiter.start_link([requests_per_second: 10, burst_size: 2, name: nil])

      # Nettoyer à la fin du test
      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      # Consommer tous les tokens
      assert :ok = RateLimiter.acquire(pid)
      assert :ok = RateLimiter.acquire(pid)

      # Attendre un peu pour que les tokens se rechargent
      :timer.sleep(300) # 300ms = 3 tokens rechargés à 10/sec

      # Devrait pouvoir faire 3 requêtes rapidement
      assert :ok = RateLimiter.acquire(pid)
      assert :ok = RateLimiter.acquire(pid)
      assert :ok = RateLimiter.acquire(pid)
    end

    test "handles multiple concurrent requests" do
      # Configuration spécifique pour ce test
      {:ok, pid} = RateLimiter.start_link([requests_per_second: 5, burst_size: 5, name: nil])

      # Nettoyer à la fin du test
      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      # Lancer 10 tâches concurrentes
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          start_time = System.monotonic_time(:millisecond)
          :ok = RateLimiter.acquire(pid)
          end_time = System.monotonic_time(:millisecond)
          end_time - start_time
        end)
      end

      results = Task.await_many(tasks, 5000)

      # Les 5 premières devraient être rapides
      fast_requests = Enum.take(Enum.sort(results), 5)
      assert Enum.all?(fast_requests, &(&1 < 100))

      # Les 5 suivantes devraient avoir attendu
      slow_requests = Enum.drop(Enum.sort(results), 5)
      assert Enum.all?(slow_requests, &(&1 >= 100))
    end
  end

  describe "get_stats/1" do
    test "returns current limiter state", %{rate_limiter: pid} do
      stats = RateLimiter.get_stats(pid)

      assert stats.requests_per_second == 10
      assert stats.burst_size == 10
      assert stats.available_tokens <= 10
      assert is_integer(stats.available_tokens)
    end
  end
end
