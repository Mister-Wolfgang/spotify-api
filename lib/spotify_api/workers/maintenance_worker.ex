defmodule SpotifyApi.Workers.MaintenanceWorker do
  @moduledoc """
  Worker qui effectue les tâches de maintenance périodiques.
  """

  use GenServer

  alias SpotifyApi.Cache.Strategies
  alias SpotifyApi.Performance.Metrics

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Programmer les tâches périodiques
    schedule_cache_warming()
    schedule_cache_analysis()
    schedule_metrics_reset()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:warm_cache, state) do
    Logger.info("Starting scheduled cache warming")
    Task.start(fn -> Strategies.warm_popular_artists() end)

    schedule_cache_warming()
    {:noreply, state}
  end

  def handle_info(:analyze_cache, state) do
    Logger.info("Starting scheduled cache analysis")
    Task.start(fn -> Strategies.analyze_cache_patterns() end)

    schedule_cache_analysis()
    {:noreply, state}
  end

  def handle_info(:reset_metrics, state) do
    Logger.info("Resetting performance metrics")
    Metrics.reset_stats()

    schedule_metrics_reset()
    {:noreply, state}
  end

  # Programmer les tâches
  defp schedule_cache_warming do
    # Cache warming toutes les 6 heures
    Process.send_after(self(), :warm_cache, :timer.hours(6))
  end

  defp schedule_cache_analysis do
    # Analyse du cache toutes les heures
    Process.send_after(self(), :analyze_cache, :timer.hours(1))
  end

  defp schedule_metrics_reset do
    # Reset des métriques tous les jours à minuit
    seconds_until_midnight = seconds_until_next_midnight()
    Process.send_after(self(), :reset_metrics, seconds_until_midnight * 1000)
  end

  defp seconds_until_next_midnight do
    now = DateTime.utc_now()
    tomorrow = DateTime.add(now, 1, :day)
    midnight = %{tomorrow | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    DateTime.diff(midnight, now, :second)
  end
end
