defmodule SpotifyApiWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for Spotify API
  """

  alias OpenApiSpex.{Components, Contact, Info, License, OpenApi, Paths, SecurityScheme, Server, Tag}
  alias SpotifyApiWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Run-time server used by SwaggerUI
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Spotify API",
        description: """
        API REST pour interagir avec les données Spotify.

        Cette API permet de :
        - Rechercher des artistes
        - Obtenir les albums d'un artiste
        - Consulter les détails d'un album
        - Récupérer les pistes d'un album
        """,
        version: "1.0.0",
        contact: %Contact{
          name: "API Support",
          email: "support@spotifyapi.com"
        },
        license: %License{
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router),
      components: %Components{
        schemas: %{
          "Artist" => SpotifyApiWeb.Schemas.Artist.schema(),
          "Album" => SpotifyApiWeb.Schemas.Album.schema(),
          "Error" => SpotifyApiWeb.Schemas.Error.schema(),
          "AlbumsResponse" => SpotifyApiWeb.Schemas.AlbumsResponse.schema()
        },
        securitySchemes: %{
          "ApiKeyAuth" => %SecurityScheme{
            type: "apiKey",
            in: "header",
            name: "X-API-Key"
          }
        }
      },
      security: [
        %{"ApiKeyAuth" => []}
      ],
      tags: [
        %Tag{
          name: "Artists",
          description: "Opérations liées aux artistes"
        }
      ]
    }
  end
end
