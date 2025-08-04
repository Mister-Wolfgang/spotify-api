defmodule SpotifyApi.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:albums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :spotify_id, :string, null: false
      add :name, :string, null: false
      add :album_type, :string
      add :release_date, :date, null: false
      add :total_tracks, :integer
      add :artist_id, references(:artists, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create unique_index(:albums, [:spotify_id])
    create index(:albums, [:artist_id])
    create index(:albums, [:release_date])
  end
end
