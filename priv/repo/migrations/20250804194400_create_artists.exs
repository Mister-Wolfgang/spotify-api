defmodule SpotifyApi.Repo.Migrations.CreateArtists do
  use Ecto.Migration

  def change do
    create table(:artists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :spotify_id, :string, null: false
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:artists, [:spotify_id])
  end
end
