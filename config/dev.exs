import Config

config :spotify_api, SpotifyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "your_secret_key_base_here",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/spotify_api_web/(controllers|views|templates|components)/.*(ex|heex)$",
      ~r"lib/spotify_api_web/layouts/.*(ex|heex)$"
    ],
    debounce: 200
  ]

# Configuration d'esbuild
config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(assets/css/app.css --bundle --target=es2017 --outfile=priv/static/css/app.css),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :spotify_api, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Configuration Spotify pour développement
config :spotify_api, :spotify,
  client_id: System.get_env("SPOTIFY_CLIENT_ID") || "your_dev_client_id",
  client_secret: System.get_env("SPOTIFY_CLIENT_SECRET") || "your_dev_client_secret",
  base_url: "https://api.spotify.com/v1",
  auth_url: "https://accounts.spotify.com/api/token"

# Configuration Rate Limiting
config :spotify_api, :rate_limiter,
  requests_per_second: 10,
  burst_size: 50
