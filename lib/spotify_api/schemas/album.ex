defmodule SpotifyApi.Schemas.Album do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "albums" do
    field :spotify_id, :string
    field :name, :string
    field :album_type, :string
    field :release_date, :date
    field :total_tracks, :integer

    belongs_to :artist, SpotifyApi.Schemas.Artist

    timestamps()
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:spotify_id, :name, :album_type, :release_date, :total_tracks, :artist_id])
    |> validate_required([:spotify_id, :name, :release_date, :artist_id])
    |> unique_constraint(:spotify_id)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:album_type, ["album", "single", "compilation"])
    |> validate_number(:total_tracks, greater_than: 0)
    |> foreign_key_constraint(:artist_id)
  end
end
