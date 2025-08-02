defmodule SpotifyApi.Spotify.AuthManager do
  @moduledoc """
  GenServer qui gère l'authentification avec l'API Spotify.
  Utilise le Client Credentials Flow et gère automatiquement
  le renouvellement des tokens.
  """

  use GenServer
  require Logger

  # Client API
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      _ -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Récupère un token d'accès valide.
  Si le token est expiré, en récupère un nouveau automatiquement.
  """
  def get_token(server \\ __MODULE__) do
    GenServer.call(server, :get_token)
  end

  # Callbacks GenServer
  @impl true
  def init(_opts) do
    state = %{
      token: nil,
      expires_at: nil,
      client: build_http_client()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_token, _from, state) do
    case get_valid_token(state) do
      {:ok, token, new_state} ->
        {:reply, {:ok, token}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  # Fonctions privées
  defp get_valid_token(state) do
    if token_valid?(state) do
      {:ok, state.token, state}
    else
      fetch_new_token(state)
    end
  end

  defp token_valid?(%{token: nil}), do: false
  defp token_valid?(%{expires_at: nil}), do: false
  defp token_valid?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end

  defp fetch_new_token(state) do
    Logger.info("Fetching new Spotify access token")

    case authenticate(state.client) do
      {:ok, token_data} ->
        new_state = update_token_state(state, token_data)
        {:ok, new_state.token, new_state}

      {:error, reason} ->
        Logger.error("Failed to authenticate with Spotify: #{inspect(reason)}")
        {:error, :authentication_failed, state}
    end
  end

  defp authenticate(client) do
    config = Application.get_env(:spotify_api, :spotify)

    # Créer l'authentification Basic selon la doc Spotify
    credentials = "#{config[:client_id]}:#{config[:client_secret]}"
    basic_auth = Base.encode64(credentials)

    # Body contient seulement grant_type selon la doc Spotify
    body = "grant_type=client_credentials"

    headers = [
      {"Authorization", "Basic #{basic_auth}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    case Tesla.post(client, config[:auth_url], body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Spotify auth failed with status #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp update_token_state(state, token_data) do
    expires_in = Map.get(token_data, "expires_in", 3600)
    expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)

    %{state |
      token: token_data["access_token"],
      expires_at: expires_at
    }
  end

  defp build_http_client do
    Tesla.client([
      Tesla.Middleware.JSON,
      Tesla.Middleware.FormUrlencoded
    ])
  end
end
