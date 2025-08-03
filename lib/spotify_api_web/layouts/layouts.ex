defmodule SpotifyApiWeb.Layouts do
  use Phoenix.Component

  def app(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <title>Spotify API Web</title>
        <link rel="stylesheet" href="/css/app.css">
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end
