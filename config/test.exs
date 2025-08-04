import Config

config :spotify_api, SpotifyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

# Configuration Spotify pour tests (mock) - OVERRIDE les vraies valeurs
config :spotify_api, :spotify,
  client_id: "test_client_id",
  client_secret: "test_client_secret",
  base_url: "http://localhost:4002/mock",
  auth_url: "http://localhost:4002/mock/token"

# Désactiver le cache en test
config :spotify_api, :cache_enabled, false

# Configuration de la base de données pour les tests
config :spotify_api, SpotifyApi.Repo,
  username: System.get_env("PGUSER") || "postgres",
  password: System.get_env("PGPASSWORD") || "mot_de_passe_test",
  hostname: System.get_env("PGHOST") || "localhost",
  database: "#{System.get_env("PGDATABASE") || "spotify_api_test"}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
