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

# Configuration Rate Limiting pour production
config :spotify_api, :rate_limiter,
  requests_per_second: 5,
  burst_size: 20
