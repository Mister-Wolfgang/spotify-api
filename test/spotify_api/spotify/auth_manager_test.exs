defmodule SpotifyApi.Spotify.AuthManagerTest do
  use ExUnit.Case, async: true
  import Mox

  alias SpotifyApi.Spotify.AuthManager

  # Setup mock
  setup :verify_on_exit!

  setup do
    # Démarrer AuthManager sans nom pour éviter les conflits
    pid = start_supervised!({AuthManager, [name: nil]})

    # Permettre au processus AuthManager d'utiliser le mock
    Mox.allow(Tesla.MockAdapter, self(), pid)

    {:ok, auth_manager: pid}
  end

  describe "get_token/0" do
    test "returns valid token when authentication succeeds", %{auth_manager: pid} do
      # Mock HTTP response
      mock_successful_auth_response()

      assert {:ok, token} = AuthManager.get_token(pid)
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "handles authentication failure", %{auth_manager: pid} do
      # Mock HTTP error response
      mock_failed_auth_response()

      assert {:error, reason} = AuthManager.get_token(pid)
      assert reason == :authentication_failed
    end

    test "reuses valid token within expiry time", %{auth_manager: pid} do
      mock_successful_auth_response()

      # Premier appel
      {:ok, token1} = AuthManager.get_token(pid)

      # Deuxième appel immédiat (doit réutiliser le token)
      {:ok, token2} = AuthManager.get_token(pid)

      assert token1 == token2
    end

    test "refreshes expired token", %{auth_manager: pid} do
      # Mock avec token qui expire très rapidement (premier appel)
      expect(Tesla.MockAdapter, :call, fn
        %Tesla.Env{method: :post, url: url}, _opts ->
          assert String.contains?(url, "token")

          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "access_token" => "short_lived_token",
              "token_type" => "Bearer",
              "expires_in" => 1  # 1 seconde seulement
            }
          }}
      end)

      {:ok, token1} = AuthManager.get_token(pid)

      # Attendre expiration
      :timer.sleep(1100)  # Plus de 1 seconde pour être sûr

      # Mock pour le deuxième appel (token refresh)
      expect(Tesla.MockAdapter, :call, fn
        %Tesla.Env{method: :post, url: url}, _opts ->
          assert String.contains?(url, "token")

          {:ok, %Tesla.Env{
            status: 200,
            body: %{
              "access_token" => "refreshed_token_new",
              "token_type" => "Bearer",
              "expires_in" => 3600
            }
          }}
      end)

      {:ok, token2} = AuthManager.get_token(pid)

      assert token1 != token2
      assert token1 == "short_lived_token"
      assert token2 == "refreshed_token_new"
    end
  end

  # Helper functions pour les mocks
  defp mock_successful_auth_response do
    # Mock Tesla HTTP client
    expect(Tesla.MockAdapter, :call, fn
      %Tesla.Env{method: :post, url: url}, _opts ->
        assert String.contains?(url, "token")

        {:ok, %Tesla.Env{
          status: 200,
          body: %{
            "access_token" => "mock_access_token_123",
            "token_type" => "Bearer",
            "expires_in" => 3600
          }
        }}
    end)
  end

  defp mock_failed_auth_response do
    expect(Tesla.MockAdapter, :call, fn
      %Tesla.Env{method: :post}, _opts ->
        {:ok, %Tesla.Env{
          status: 400,
          body: %{"error" => "invalid_client"}
        }}
    end)
  end
end
