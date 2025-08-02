defmodule SpotifyApiWeb.FallbackController do
  use SpotifyApiWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{
      error: "not_found",
      message: "The requested resource was not found",
      path: conn.request_path,
      method: conn.method
    })
  end
end
