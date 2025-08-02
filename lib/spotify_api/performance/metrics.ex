defmodule SpotifyApi.Performance.Metrics do
  @moduledoc """
  Module pour collecter et exposer les métriques de performance.
  """

  use GenServer
  require Logger

  defstruct [
    :requests_count,
    :total_response_time,
    :cache_hits,
    :cache_misses,
    :spotify_api_calls,
    :errors_count
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # API publique
  def record_request(response_time_ms) do
    GenServer.cast(__MODULE__, {:request, response_time_ms})
  end

  def record_cache_hit do
    GenServer.cast(__MODULE__, :cache_hit)
  end

  def record_cache_miss do
    GenServer.cast(__MODULE__, :cache_miss)
  end

  def record_spotify_call do
    GenServer.cast(__MODULE__, :spotify_call)
  end

  def record_error do
    GenServer.cast(__MODULE__, :error)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def reset_stats do
    GenServer.cast(__MODULE__, :reset)
  end

  # Callbacks GenServer
  @impl true
  def init(_opts) do
    # Log stats every 5 minutes
    :timer.send_interval(:timer.minutes(5), :log_stats)

    {:ok, %__MODULE__{
      requests_count: 0,
      total_response_time: 0,
      cache_hits: 0,
      cache_misses: 0,
      spotify_api_calls: 0,
      errors_count: 0
    }}
  end

  @impl true
  def handle_cast({:request, response_time}, state) do
    new_state = %{state |
      requests_count: state.requests_count + 1,
      total_response_time: state.total_response_time + response_time
    }
    {:noreply, new_state}
  end

  def handle_cast(:cache_hit, state) do
    {:noreply, %{state | cache_hits: state.cache_hits + 1}}
  end

  def handle_cast(:cache_miss, state) do
    {:noreply, %{state | cache_misses: state.cache_misses + 1}}
  end

  def handle_cast(:spotify_call, state) do
    {:noreply, %{state | spotify_api_calls: state.spotify_api_calls + 1}}
  end

  def handle_cast(:error, state) do
    {:noreply, %{state | errors_count: state.errors_count + 1}}
  end

  def handle_cast(:reset, _state) do
    {:noreply, %__MODULE__{
      requests_count: 0,
      total_response_time: 0,
      cache_hits: 0,
      cache_misses: 0,
      spotify_api_calls: 0,
      errors_count: 0
    }}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = calculate_stats(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:log_stats, state) do
    stats = calculate_stats(state)
    Logger.info("Performance stats: #{format_stats(stats)}")
    {:noreply, state}
  end

  # Fonctions privées
  defp calculate_stats(state) do
    avg_response_time = if state.requests_count > 0 do
      state.total_response_time / state.requests_count
    else
      0
    end

    cache_total = state.cache_hits + state.cache_misses
    cache_hit_rate = if cache_total > 0 do
      (state.cache_hits / cache_total * 100) |> Float.round(2)
    else
      0.0
    end

    %{
      requests_count: state.requests_count,
      average_response_time_ms: Float.round(avg_response_time, 2),
      cache_hit_rate_percent: cache_hit_rate,
      cache_hits: state.cache_hits,
      cache_misses: state.cache_misses,
      spotify_api_calls: state.spotify_api_calls,
      errors_count: state.errors_count,
      error_rate_percent: if state.requests_count > 0 do
        (state.errors_count / state.requests_count * 100) |> Float.round(2)
      else
        0.0
      end
    }
  end

  defp format_stats(stats) do
    "requests=#{stats.requests_count} " <>
    "avg_time=#{stats.average_response_time_ms}ms " <>
    "cache_hit_rate=#{stats.cache_hit_rate_percent}% " <>
    "spotify_calls=#{stats.spotify_api_calls} " <>
    "errors=#{stats.errors_count}"
  end
end
