import Config

config :tesla, disable_deprecated_builder_warning: true

config :spotify_api, SpotifyApiWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: SpotifyApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SpotifyApi.PubSub,
  live_view: [signing_salt: "your_signing_salt"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Configuration Ecto
config :spotify_api,
  ecto_repos: [SpotifyApi.Repo]

# Configuration Tesla (HTTP client)
config :tesla, adapter: Tesla.Adapter.Hackney

# Configuration Cachex
config :cachex,
  default_ttl: :timer.minutes(30)

import_config "#{config_env()}.exs"
