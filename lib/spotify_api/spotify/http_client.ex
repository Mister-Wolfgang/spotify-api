defmodule SpotifyApi.Spotify.HttpClient do
  @moduledoc """
  Client HTTP pour l'API Spotify avec rate limiting intégré.
  """

  alias SpotifyApi.RateLimiter
  alias SpotifyApi.Spotify.AuthManager

  require Logger

  @base_url "https://api.spotify.com/v1"

  def get(path, opts \\ []) do
    make_request(:get, path, nil, opts)
  end

  def post(path, body, opts \\ []) do
    make_request(:post, path, body, opts)
  end

  defp make_request(method, path, body, opts) do
    # Utiliser les instances spécifiques ou les services nommés par défaut
    rate_limiter = Keyword.get(opts, :rate_limiter, SpotifyApi.RateLimiter)
    auth_manager = Keyword.get(opts, :auth_manager, SpotifyApi.Spotify.AuthManager)

    # Acquérir un token du rate limiter
    :ok = RateLimiter.acquire(rate_limiter)

    # Obtenir le token d'authentification
    case AuthManager.get_token(auth_manager) do
      {:ok, token} ->
        execute_request(method, build_url(path), body, token, opts)

      {:error, reason} ->
        {:error, {:auth_failed, reason}}
    end
  end

  defp execute_request(method, url, body, token, opts) do
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ] ++ Keyword.get(opts, :headers, [])

    client = Tesla.client([
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry, delay: 1000, max_retries: 3}
    ])

    request_opts = [headers: headers]

    case method do
      :get -> Tesla.get(client, url, request_opts)
      :post -> Tesla.post(client, url, body, request_opts)
    end
    |> case do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: 429, headers: headers}} ->
        # Rate limit atteint côté Spotify
        retry_after = get_retry_after_header(headers)
        Logger.warning("Spotify rate limit reached, retrying after #{retry_after}ms")
        :timer.sleep(retry_after)
        execute_request(method, url, body, token, opts)

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Spotify API error #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp build_url(path) do
    @base_url <> "/" <> String.trim_leading(path, "/")
  end

  defp get_retry_after_header(headers) do
    case List.keyfind(headers, "retry-after", 0) do
      {_, value} when is_binary(value) ->
        case Integer.parse(value) do
          {seconds, _} -> seconds * 1000  # Convertir en millisecondes
          :error -> 1000  # Default 1 seconde
        end
      _ ->
        1000  # Default 1 seconde
    end
  end
end
