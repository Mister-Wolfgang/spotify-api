defmodule SpotifyApiWeb.Plugs.RequestLogger do
  @moduledoc """
  Plug pour logger les requêtes API avec des métriques.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    conn
    |> assign(:request_start_time, start_time)
    |> register_before_send(&log_request/1)
  end

  defp log_request(conn) do
    start_time = conn.assigns[:request_start_time]
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info([
      "API Request - ",
      "method=", conn.method, " ",
      "path=", conn.request_path, " ",
      "status=", Integer.to_string(conn.status), " ",
      "duration=", Integer.to_string(duration), "ms ",
      "ip=", get_client_ip(conn)
    ])

    conn
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] -> forwarded |> String.split(",") |> List.first() |> String.trim()
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
