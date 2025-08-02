defmodule SpotifyApiWeb.Schemas do
  @moduledoc """
  Schémas OpenAPI pour l'API Spotify
  """
  alias OpenApiSpex.Schema

  defmodule Error do
    @moduledoc "Schéma pour les erreurs de l'API"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Error",
      description: "Réponse d'erreur de l'API",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Message d'erreur", example: "Resource not found"},
        code: %Schema{type: :integer, description: "Code d'erreur HTTP", example: 404},
        details: %Schema{type: :string, description: "Détails additionnels", example: "Artist not found"}
      },
      required: [:error, :code],
      example: %{
        "error" => "Resource not found",
        "code" => 404,
        "details" => "The requested artist could not be found"
      }
    })
  end

  defmodule Artist do
    @moduledoc "Schéma pour un artiste Spotify"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Artist",
      description: "Informations sur un artiste Spotify",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Identifiant unique", example: "4Z8W4fKeB5YxbusRsdQVPb"},
        name: %Schema{type: :string, description: "Nom de l'artiste", example: "Radiohead"},
        followers: %Schema{type: :integer, description: "Nombre de followers", example: 4234567},
        popularity: %Schema{type: :integer, description: "Score de popularité (0-100)", minimum: 0, maximum: 100, example: 82},
        genres: %Schema{type: :array, items: %Schema{type: :string}, description: "Genres musicaux", example: ["alternative rock", "art rock"]},
        external_urls: %Schema{
          type: :object,
          description: "URLs externes",
          properties: %{
            spotify: %Schema{type: :string, format: :uri, description: "URL Spotify", example: "https://open.spotify.com/artist/4Z8W4fKeB5YxbusRsdQVPb"}
          }
        }
      },
      required: [:id, :name],
      example: %{
        "id" => "4Z8W4fKeB5YxbusRsdQVPb",
        "name" => "Radiohead",
        "followers" => 4234567,
        "popularity" => 82,
        "genres" => ["alternative rock", "art rock", "electronic"],
        "external_urls" => %{"spotify" => "https://open.spotify.com/artist/4Z8W4fKeB5YxbusRsdQVPb"}
      }
    })
  end

  defmodule Album do
    @moduledoc "Schéma pour un album Spotify"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Album",
      description: "Informations sur un album Spotify",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Identifiant unique", example: "2guirTSEqLizK7j9i1MTTZ"},
        name: %Schema{type: :string, description: "Nom de l'album", example: "OK Computer"},
        album_type: %Schema{type: :string, description: "Type d'album", enum: ["album", "single", "compilation"], example: "album"},
        release_date: %Schema{type: :string, format: :date, description: "Date de sortie", example: "1997-07-01"},
        total_tracks: %Schema{type: :integer, description: "Nombre total de pistes", example: 12},
        artists: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, example: "4Z8W4fKeB5YxbusRsdQVPb"},
              name: %Schema{type: :string, example: "Radiohead"}
            }
          },
          description: "Artistes de l'album"
        },
        external_urls: %Schema{
          type: :object,
          properties: %{
            spotify: %Schema{type: :string, format: :uri, example: "https://open.spotify.com/album/2guirTSEqLizK7j9i1MTTZ"}
          }
        }
      },
      required: [:id, :name, :album_type, :release_date, :total_tracks, :artists],
      example: %{
        "id" => "2guirTSEqLizK7j9i1MTTZ",
        "name" => "OK Computer",
        "album_type" => "album",
        "release_date" => "1997-07-01",
        "total_tracks" => 12,
        "artists" => [%{"id" => "4Z8W4fKeB5YxbusRsdQVPb", "name" => "Radiohead"}],
        "external_urls" => %{"spotify" => "https://open.spotify.com/album/2guirTSEqLizK7j9i1MTTZ"}
      }
    })
  end

  defmodule AlbumsResponse do
    @moduledoc "Schéma pour la réponse de la liste des albums"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AlbumsResponse",
      description: "Réponse contenant la liste des albums d'un artiste",
      type: :object,
      properties: %{
        albums: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, example: "2guirTSEqLizK7j9i1MTTZ"},
              name: %Schema{type: :string, example: "OK Computer"},
              album_type: %Schema{type: :string, example: "album"},
              release_date: %Schema{type: :string, example: "1997-07-01"},
              total_tracks: %Schema{type: :integer, example: 12}
            }
          },
          description: "Liste des albums"
        },
        total: %Schema{type: :integer, description: "Nombre total d'albums", example: 15},
        artist: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, example: "4Z8W4fKeB5YxbusRsdQVPb"},
            name: %Schema{type: :string, example: "Radiohead"}
          }
        }
      },
      required: [:albums, :total, :artist],
      example: %{
        "albums" => [
          %{
            "id" => "2guirTSEqLizK7j9i1MTTZ",
            "name" => "OK Computer",
            "album_type" => "album",
            "release_date" => "1997-07-01",
            "total_tracks" => 12
          }
        ],
        "total" => 15,
        "artist" => %{"id" => "4Z8W4fKeB5YxbusRsdQVPb", "name" => "Radiohead"}
      }
    })
  end
end
