import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :spotify_api, SpotifyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "j9poMLoI0oKWRybQNjkQKE3uB9PzPcQWctON8x3hF7hE9pRf7YYaYR0PZdjck9qM",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
