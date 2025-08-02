defmodule SpotifyApi.Spotify.HttpClientTest do
  use ExUnit.Case, async: true
  import Mox

  alias SpotifyApi.Spotify.HttpClient

  setup :verify_on_exit!

  setup do
    # Démarrer les services supervisés pour chaque test (sans nom)
    rate_limiter = start_supervised!({SpotifyApi.RateLimiter, [requests_per_second: 100, burst_size: 100, name: nil]})
    auth_manager = start_supervised!({SpotifyApi.Spotify.AuthManager, [name: nil]})

    # Permettre aux processus d'utiliser les mocks
    Mox.allow(Tesla.MockAdapter, self(), rate_limiter)
    Mox.allow(Tesla.MockAdapter, self(), auth_manager)

    {:ok, rate_limiter: rate_limiter, auth_manager: auth_manager}
  end

  describe "get/2" do
    test "makes successful request with rate limiting", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      # Mock auth manager
      mock_auth_success()

      # Mock HTTP response
      expect(Tesla.MockAdapter, :call, fn
        %Tesla.Env{method: :get, url: url, headers: headers}, _opts ->
          assert String.contains?(url, "spotify.com")
          assert {"Authorization", "Bearer mock_token"} in headers

          {:ok, %Tesla.Env{
            status: 200,
            body: %{"test" => "data"}
          }}
      end)

      assert {:ok, %{"test" => "data"}} = HttpClient.get("/test", rate_limiter: rate_limiter, auth_manager: auth_manager)
    end

    test "handles rate limit from Spotify API", %{rate_limiter: rate_limiter, auth_manager: auth_manager} do
      mock_auth_success()

      # Mock 429 response puis succès
      expect(Tesla.MockAdapter, :call, 2, fn
        %Tesla.Env{method: :get}, _opts ->
          {:ok, %Tesla.Env{
            status: 429,
            headers: [{"retry-after", "1"}]
          }}
      end)

      expect(Tesla.MockAdapter, :call, fn
        %Tesla.Env{method: :get}, _opts ->
          {:ok, %Tesla.Env{
            status: 200,
            body: %{"success" => true}
          }}
      end)

      assert {:ok, %{"success" => true}} = HttpClient.get("/test", rate_limiter: rate_limiter, auth_manager: auth_manager)
    end
  end

  defp mock_auth_success do
    expect(Tesla.MockAdapter, :call, fn
      %Tesla.Env{method: :post, url: url}, _opts ->
        if String.contains?(url, "token") do
          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "access_token" => "mock_token",
              "token_type" => "Bearer",
              "expires_in" => 3600
            }
          }}
        end
    end)
  end
end
