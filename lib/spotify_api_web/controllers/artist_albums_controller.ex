defmodule SpotifyApiWeb.ArtistAlbumsController do
  use SpotifyApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias SpotifyApi.Features.ArtistAlbums
  alias SpotifyApi.Formatters.AlbumFormatter
  alias OpenApiSpex.Operation

  require Logger

  operation :index,
    summary: "Récupérer les albums d'un artiste",
    description: """
    Récupère la liste complète des albums d'un artiste Spotify, triés par date de sortie.

    L'API recherche d'abord l'artiste par nom, puis récupère tous ses albums.
    Les résultats sont mis en cache pour améliorer les performances.
    """,
    parameters: [
      Operation.parameter(:name, :path, :string, "Nom de l'artiste à rechercher",
        example: "Radiohead", required: true),
      Operation.parameter(:album_types, :query, :string,
        "Types d'albums à inclure (séparés par des virgules)",
        example: "album,single", required: false),
      Operation.parameter(:limit, :query, :integer,
        "Nombre maximum d'albums à retourner (1-200)",
        example: 50, required: false)
    ],
    responses: %{
      200 => Operation.response("Albums récupérés avec succès", "application/json", %OpenApiSpex.Reference{:"$ref" => "#/components/schemas/AlbumsResponse"}),
      400 => Operation.response("Paramètres invalides", "application/json", %OpenApiSpex.Reference{:"$ref" => "#/components/schemas/Error"}),
      404 => Operation.response("Artiste non trouvé", "application/json", %OpenApiSpex.Reference{:"$ref" => "#/components/schemas/Error"}),
      500 => Operation.response("Erreur interne", "application/json", %OpenApiSpex.Reference{:"$ref" => "#/components/schemas/Error"})
    },
    tags: ["Artists"]

  def index(conn, %{"name" => artist_name} = params) do
    # Validation et nettoyage du nom d'artiste
    case validate_artist_name(artist_name) do
      {:ok, clean_name} ->
        opts = build_options(params)
        handle_albums_request(conn, clean_name, opts)

      {:error, reason} ->
        send_error(conn, 400, :invalid_artist_name, reason)
    end
  end

  def index(conn, _params) do
    send_error(conn, 400, :missing_artist_name, "Artist name is required")
  end

  # Fonctions privées

  defp validate_artist_name(name) when is_binary(name) do
    cleaned = String.trim(name)

    cond do
      cleaned == "" ->
        {:error, "Artist name cannot be empty"}

      String.length(cleaned) > 100 ->
        {:error, "Artist name too long (max 100 characters)"}

      String.match?(cleaned, ~r/^[\s\p{L}\p{N}\p{P}]+$/u) ->
        {:ok, cleaned}

      true ->
        {:error, "Artist name contains invalid characters"}
    end
  end

  defp validate_artist_name(_), do: {:error, "Artist name must be a string"}

  defp build_options(params) do
    []
    |> add_album_types_option(params)
    |> add_limit_option(params)
  end

  defp add_album_types_option(opts, %{"album_types" => types_string}) do
    case parse_album_types(types_string) do
      {:ok, types} -> Keyword.put(opts, :album_types, types)
      {:error, _} -> opts  # Ignorer les types invalides
    end
  end
  defp add_album_types_option(opts, _), do: opts

  defp add_limit_option(opts, %{"limit" => limit_string}) do
    case parse_limit(limit_string) do
      {:ok, limit} -> Keyword.put(opts, :limit, limit)
      {:error, _} -> opts  # Ignorer les limites invalides
    end
  end
  defp add_limit_option(opts, _), do: opts

  defp parse_album_types(types_string) when is_binary(types_string) do
    valid_types = ["album", "single", "compilation", "appears_on"]

    types =
      types_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 in valid_types))

    if length(types) > 0 do
      {:ok, types}
    else
      {:error, "No valid album types provided"}
    end
  end
  defp parse_album_types(_), do: {:error, "Invalid album types format"}

  defp parse_limit(limit_string) when is_binary(limit_string) do
    case Integer.parse(limit_string) do
      {limit, ""} when limit > 0 and limit <= 200 ->
        {:ok, limit}

      {limit, ""} when limit > 200 ->
        {:ok, 200}  # Cap à 200

      _ ->
        {:error, "Invalid limit"}
    end
  end
  defp parse_limit(_), do: {:error, "Invalid limit format"}

  defp handle_albums_request(conn, artist_name, opts) do
    Logger.info("Processing albums request for artist: #{artist_name}")
    start_time = System.monotonic_time(:millisecond)

    case ArtistAlbums.get_albums(artist_name, opts) do
      {:ok, %{"artist" => resolved_name, "albums" => albums}} ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.info("Albums request completed in #{duration}ms")
        Logger.info("Nom demandé: #{artist_name} / Nom résolu: #{resolved_name}")

        response = AlbumFormatter.format_albums_response(albums, resolved_name)

        conn
        |> put_resp_header("x-response-time", "#{duration}ms")
        |> put_resp_header("cache-control", "public, max-age=1800")
        |> json(response)

      {:error, :artist_not_found} ->
        send_error(conn, 404, :artist_not_found, "Artist '#{artist_name}' not found")

      {:error, :no_albums_found} ->
        response = AlbumFormatter.format_error_response(:no_albums_found, artist_name)
        json(conn, response)

      {:error, reason} ->
        Logger.error("Albums request failed for #{artist_name}: #{inspect(reason)}")
        send_error(conn, 500, :api_error, "Failed to retrieve albums")
    end
  end

  defp send_error(conn, status, error_type, message) do
    response = %{
      error: Atom.to_string(error_type),
      message: message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    conn
    |> put_status(status)
    |> json(response)
  end
end
