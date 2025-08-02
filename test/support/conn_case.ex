defmodule SpotifyApiWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use SpotifyApiWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint SpotifyApiWeb.Endpoint

      use SpotifyApiWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import SpotifyApiWeb.ConnCase
      import Mox
    end
  end

  setup _tags do
    # Démarrer les services nécessaires pour les tests de contrôleurs avec leurs noms par défaut
    rate_limiter = start_supervised!({SpotifyApi.RateLimiter, [requests_per_second: 100, burst_size: 100, name: SpotifyApi.RateLimiter]})
    auth_manager = start_supervised!({SpotifyApi.Spotify.AuthManager, [name: SpotifyApi.Spotify.AuthManager]})

    # Permettre aux processus d'utiliser les mocks
    Mox.allow(Tesla.MockAdapter, self(), rate_limiter)
    Mox.allow(Tesla.MockAdapter, self(), auth_manager)

    # Vider le cache pour éviter les interférences entre tests
    SpotifyApi.Cache.clear()

    {:ok, conn: Phoenix.ConnTest.build_conn(), rate_limiter: rate_limiter, auth_manager: auth_manager}
  end
end
