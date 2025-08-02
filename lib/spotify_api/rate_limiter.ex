defmodule SpotifyApi.RateLimiter do
  @moduledoc """
  Rate limiter utilisant l'algorithme Token Bucket.
  Limite le nombre de requêtes par seconde vers l'API Spotify.
  """

  use GenServer
  require Logger

  @default_requests_per_second 10
  @default_burst_size 50

  # Structure pour l'état interne
  defstruct [
    :requests_per_second,
    :burst_size,
    :available_tokens,
    :last_refill_time,
    :waiting_queue
  ]

  # Client API
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      _ -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Acquiert un token pour faire une requête.
  Bloque si aucun token n'est disponible.
  """
  def acquire(server \\ __MODULE__) do
    GenServer.call(server, :acquire, :infinity)
  end

  @doc """
  Retourne les statistiques actuelles du rate limiter.
  """
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  # Callbacks GenServer
  @impl true
  def init(opts) do
    config = Application.get_env(:spotify_api, :rate_limiter, [])

    state = %__MODULE__{
      requests_per_second: opts[:requests_per_second] || config[:requests_per_second] || @default_requests_per_second,
      burst_size: opts[:burst_size] || config[:burst_size] || @default_burst_size,
      available_tokens: opts[:burst_size] || config[:burst_size] || @default_burst_size,
      last_refill_time: System.monotonic_time(:millisecond),
      waiting_queue: :queue.new()
    }

    # Programmer le rechargement périodique des tokens
    schedule_refill()

    {:ok, state}
  end

  @impl true
  def handle_call(:acquire, from, state) do
    state = refill_tokens(state)

    if state.available_tokens > 0 do
      # Token disponible, répondre immédiatement
      new_state = %{state | available_tokens: state.available_tokens - 1}
      {:reply, :ok, new_state}
    else
      # Pas de token, ajouter à la queue d'attente
      new_queue = :queue.in(from, state.waiting_queue)
      new_state = %{state | waiting_queue: new_queue}
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    state = refill_tokens(state)

    stats = %{
      requests_per_second: state.requests_per_second,
      burst_size: state.burst_size,
      available_tokens: state.available_tokens,
      queue_length: :queue.len(state.waiting_queue)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:refill, state) do
    state = refill_tokens(state)
    state = process_waiting_queue(state)

    schedule_refill()
    {:noreply, state}
  end

  # Fonctions privées
  defp refill_tokens(state) do
    now = System.monotonic_time(:millisecond)
    time_passed = now - state.last_refill_time

    # Calculer combien de tokens ajouter (proportionnel au temps écoulé)
    tokens_to_add = div(time_passed * state.requests_per_second, 1000)

    if tokens_to_add > 0 do
      new_tokens = min(
        state.available_tokens + tokens_to_add,
        state.burst_size
      )

      %{state |
        available_tokens: new_tokens,
        last_refill_time: now
      }
    else
      state
    end
  end

  defp process_waiting_queue(state) do
    process_waiting_queue_recursive(state)
  end

  defp process_waiting_queue_recursive(%{available_tokens: 0} = state), do: state
  defp process_waiting_queue_recursive(state) do
    case :queue.out(state.waiting_queue) do
      {{:value, from}, new_queue} ->
        # Répondre au client en attente
        GenServer.reply(from, :ok)

        new_state = %{state |
          available_tokens: state.available_tokens - 1,
          waiting_queue: new_queue
        }

        process_waiting_queue_recursive(new_state)

      {:empty, _queue} ->
        state
    end
  end

  defp schedule_refill do
    # Programmer le prochain rechargement dans 100ms
    Process.send_after(self(), :refill, 100)
  end
end
