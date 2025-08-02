defmodule SpotifyApi.Cache.StatsWorker do
  @moduledoc """
  Worker qui log périodiquement les statistiques du cache.
  """

  use GenServer
  require Logger

  @stats_interval :timer.minutes(5)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_stats()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:log_stats, state) do
    log_cache_stats()
    schedule_stats()
    {:noreply, state}
  end

  defp schedule_stats do
    Process.send_after(self(), :log_stats, @stats_interval)
  end

  defp log_cache_stats do
    case Cachex.stats(:spotify_cache) do
      {:ok, stats} ->
        Logger.info("Cache stats: #{format_stats(stats)}")
      {:error, reason} ->
        Logger.error("Failed to get cache stats: #{inspect(reason)}")
    end
  end

  defp format_stats(stats) do
    hit_rate = case stats.hit_count + stats.miss_count do
      0 -> 0.0
      total -> (stats.hit_count / total * 100) |> Float.round(2)
    end

    "hits: #{stats.hit_count}, " <>
    "misses: #{stats.miss_count}, " <>
    "hit_rate: #{hit_rate}%, " <>
    "evictions: #{stats.eviction_count}"
  end
end
