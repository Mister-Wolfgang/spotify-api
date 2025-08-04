defmodule SpotifyApi.Schemas.Artist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "artists" do
    field :spotify_id, :string
    field :name, :string

    has_many :albums, SpotifyApi.Schemas.Album

    timestamps()
  end

  @doc false
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:spotify_id, :name])
    |> validate_required([:spotify_id, :name])
    |> unique_constraint(:spotify_id)
    |> validate_length(:name, min: 1, max: 255)
  end
end
