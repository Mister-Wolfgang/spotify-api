defmodule SpotifyApiWeb.HealthController do
  use SpotifyApiWeb, :controller

  alias SpotifyApi.Spotify.AuthManager

  def index(conn, _params) do
    health_status = check_system_health()

    status_code = if health_status.healthy, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(health_status)
  end

  defp check_system_health do
    checks = %{
      cache: check_cache(),
      spotify_auth: check_spotify_auth(),
      memory: check_memory_usage()
    }

    healthy = Enum.all?(checks, fn {_service, status} -> status.healthy end)

    %{
      healthy: healthy,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:spotify_api, :vsn) |> to_string(),
      checks: checks
    }
  end

  defp check_cache do
    try do
      Cachex.put(:spotify_cache, "health_check", "ok", ttl: 1000)

      case Cachex.get(:spotify_cache, "health_check") do
        {:ok, "ok"} ->
          Cachex.del(:spotify_cache, "health_check")
          %{healthy: true, message: "Cache operational"}

        _ ->
          %{healthy: false, message: "Cache read failed"}
      end
    rescue
      error ->
        %{healthy: false, message: "Cache error: #{inspect(error)}"}
    end
  end

  defp check_spotify_auth do
    case AuthManager.get_token() do
      {:ok, _token} ->
        %{healthy: true, message: "Spotify authentication operational"}

      {:error, reason} ->
        %{healthy: false, message: "Spotify auth failed: #{inspect(reason)}"}
    end
  end

  defp check_memory_usage do
    memory_info = :erlang.memory()
    total_mb = div(memory_info[:total], 1024 * 1024)

    # Seuil d'alerte à 500MB
    healthy = total_mb < 500

    %{
      healthy: healthy,
      message: "Memory usage: #{total_mb}MB",
      details: %{
        total_mb: total_mb,
        processes_mb: div(memory_info[:processes], 1024 * 1024),
        ets_mb: div(memory_info[:ets], 1024 * 1024)
      }
    }
  end
end
