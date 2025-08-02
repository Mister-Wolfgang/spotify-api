defmodule SpotifyApiWeb.Plugs.RateLimiter do
  @moduledoc """
  Plug pour limiter le nombre de requêtes par IP.
  """

  import Plug.Conn
  require Logger

  @default_limit 100  # requêtes par heure
  @default_window :timer.hours(1)

  def init(opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    window = Keyword.get(opts, :window, @default_window)

    %{limit: limit, window: window}
  end

  def call(conn, %{limit: limit, window: window}) do
    client_ip = get_client_ip(conn)
    key = "rate_limit:#{client_ip}"

    case check_rate_limit(key, limit, window) do
      :ok ->
        conn

      {:error, :rate_limited, retry_after} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> put_resp_header("x-ratelimit-limit", Integer.to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> send_resp(429, Jason.encode!(%{
          error: "rate_limited",
          message: "Too many requests. Please try again later.",
          retry_after: retry_after
        }))
        |> halt()
    end
  end

  defp get_client_ip(conn) do
    # Vérifier les headers de proxy en premier
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [real_ip | _] -> real_ip
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end

  defp check_rate_limit(key, limit, window) do
    current_time = System.system_time(:second)
    window_start = current_time - div(window, 1000)

    case Cachex.get(:spotify_cache, key) do
      {:ok, nil} ->
        # Première requête
        Cachex.put(:spotify_cache, key, [current_time], ttl: window)
        :ok

      {:ok, timestamps} ->
        # Filtrer les timestamps dans la fenêtre courante
        valid_timestamps = Enum.filter(timestamps, &(&1 > window_start))

        if length(valid_timestamps) >= limit do
          # Rate limit atteint
          oldest_timestamp = Enum.min(valid_timestamps)
          retry_after = oldest_timestamp + div(window, 1000) - current_time
          {:error, :rate_limited, max(retry_after, 1)}
        else
          # Ajouter le timestamp courant
          new_timestamps = [current_time | valid_timestamps]
          Cachex.put(:spotify_cache, key, new_timestamps, ttl: window)
          :ok
        end
    end
  end
end
