import Config

config :spotify_api, SpotifyApiWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

# Configuration Spotify pour production
config :spotify_api, :spotify,
  client_id: System.get_env("SPOTIFY_CLIENT_ID"),
  client_secret: System.get_env("SPOTIFY_CLIENT_SECRET"),
  base_url: "https://api.spotify.com/v1",
  auth_url: "https://accounts.spotify.com/api/token"
# Configuration de la base PostgreSQL pour production
config :spotify_api, SpotifyApi.Repo,
  username: System.get_env("PGUSER"),
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST"),
  database: System.get_env("PGDATABASE"),
  pool_size: 15

# Configuration Rate Limiting pour production
config :spotify_api, :rate_limiter,
  requests_per_second: 5,
  burst_size: 20
