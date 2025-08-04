defmodule SpotifyApi.Repo do
  use Ecto.Repo,
    otp_app: :spotify_api,
    adapter: Ecto.Adapters.Postgres
end
