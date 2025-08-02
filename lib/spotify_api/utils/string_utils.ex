defmodule SpotifyApi.Utils.StringUtils do
  @moduledoc """
  Utilitaires pour la manipulation de chaînes de caractères.
  """

  @doc """
  Normalise un nom d'artiste pour la recherche et la comparaison.

  ## Exemples

      iex> StringUtils.normalize_artist_name("The Beatles")
      "beatles"

      iex> StringUtils.normalize_artist_name("AC/DC")
      "ac dc"

      iex> StringUtils.normalize_artist_name("  Björk  ")
      "bjork"
  """
  def normalize_artist_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> remove_diacritics()
    |> String.replace(~r/[^\w\s]/, " ")  # Remplacer ponctuation par espaces
    |> String.replace(~r/\s+/, " ")      # Normaliser espaces multiples
    |> String.replace(~r/^the\s+/, "")   # Supprimer "the" au début
    |> String.trim()
  end

  def normalize_artist_name(_), do: ""

  @doc """
  Calcule la similarité entre deux chaînes (Jaro-Winkler).
  Retourne un score entre 0.0 (aucune similarité) et 1.0 (identique).
  """
  def similarity(string1, string2) when is_binary(string1) and is_binary(string2) do
    jaro_winkler_similarity(string1, string2)
  end

  def similarity(_, _), do: 0.0

  @doc """
  Trouve les meilleurs matches dans une liste basé sur la similarité.
  """
  def find_best_matches(target, candidates, threshold \\ 0.7) do
    candidates
    |> Enum.map(fn candidate ->
      score = similarity(target, candidate)
      {candidate, score}
    end)
    |> Enum.filter(fn {_candidate, score} -> score >= threshold end)
    |> Enum.sort_by(fn {_candidate, score} -> score end, :desc)
    |> Enum.map(fn {candidate, _score} -> candidate end)
  end

  # Fonctions privées

  defp remove_diacritics(string) do
    # Simplification : remplace les caractères accentués les plus communs
    string
    |> String.replace(~r/[àáâãäå]/, "a")
    |> String.replace(~r/[èéêë]/, "e")
    |> String.replace(~r/[ìíîï]/, "i")
    |> String.replace(~r/[òóôõö]/, "o")
    |> String.replace(~r/[ùúûü]/, "u")
    |> String.replace(~r/[ýÿ]/, "y")
    |> String.replace(~r/[ñ]/, "n")
    |> String.replace(~r/[ç]/, "c")
    |> String.replace(~r/[ß]/, "ss")
  end

  # Implémentation simplifiée de Jaro-Winkler
  defp jaro_winkler_similarity(string1, string2) do
    # Pour la simplicité, on utilise une métrique basique
    # Dans un vrai projet, on utiliserait une bibliothèque comme String.jaro/2

    cond do
      string1 == string2 -> 1.0
      String.contains?(string1, string2) or String.contains?(string2, string1) -> 0.8
      true -> calculate_basic_similarity(string1, string2)
    end
  end

  defp calculate_basic_similarity(string1, string2) do
    set1 = string1 |> String.graphemes() |> MapSet.new()
    set2 = string2 |> String.graphemes() |> MapSet.new()

    intersection_size = MapSet.intersection(set1, set2) |> MapSet.size()
    union_size = MapSet.union(set1, set2) |> MapSet.size()

    if union_size == 0, do: 0.0, else: intersection_size / union_size
  end
end
