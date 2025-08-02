defmodule SpotifyApi.Spotify.Artists do
  @moduledoc """
  Module pour la recherche et récupération d'informations sur les artistes Spotify.
  """

  alias SpotifyApi.Spotify.HttpClient
  alias SpotifyApi.Cache

  require Logger

  @doc """
  Recherche des artistes par nom.
  Utilise le cache pour éviter les appels répétés.
  """
  def search(artist_name, opts \\ []) when is_binary(artist_name) do
    normalized_name = normalize_artist_name(artist_name)
    cache_key = Cache.artist_search_key(normalized_name)

    Logger.info("🔄 SEARCH: Recherche pour '#{artist_name}' → '#{normalized_name}' | Cache key: #{cache_key}")

    # Pour le debug, forcer bypass du cache si demandé
    if Keyword.get(opts, :bypass_cache, false) do
      Logger.info("🔄 BYPASS CACHE: Suppression du cache et nouvelle recherche")
      Cache.delete(cache_key)
    end

    Cache.fetch(
      cache_key,
      fn -> fetch_artists_from_spotify(normalized_name, opts) end,
      ttl: :timer.hours(2)
    )
  end

  @doc """
  Récupère les détails d'un artiste par son ID Spotify.
  """
  def get_artist_by_id(artist_id, opts \\ []) when is_binary(artist_id) do
    cache_key = "artist:#{artist_id}"

    Cache.fetch(
      cache_key,
      fn -> fetch_artist_by_id_from_spotify(artist_id, opts) end,
      ttl: :timer.hours(6)
    )
  end

  @doc """
  Trouve le meilleur match parmi une liste d'artistes candidats.
  Utilise d'abord la correspondance exacte, puis la logique fuzzy améliorée.
  """
  def find_best_match(_search_term, []), do: nil
  def find_best_match(search_term, candidates) when is_list(candidates) do
    normalized_search = normalize_artist_name(search_term)

    Logger.info("🎯 MATCHING START: Recherche '#{search_term}' → normalisé: '#{normalized_search}' parmi #{length(candidates)} candidats")

    # Log tous les candidats avec leurs noms normalisés
    Enum.with_index(candidates, 1)
    |> Enum.each(fn {artist, index} ->
      normalized_candidate = normalize_artist_name(artist["name"])
      popularity = get_popularity(artist)
      Logger.info("🎯 CANDIDAT #{index}: '#{artist["name"]}' → '#{normalized_candidate}' | Pop: #{popularity} | ID: #{artist["id"]}")
    end)

    # 1. Chercher d'abord une correspondance exacte
    exact_match = Enum.find(candidates, fn artist ->
      normalize_artist_name(artist["name"]) == normalized_search
    end)

    case exact_match do
      nil ->
        Logger.info("🎯 EXACT: Aucune correspondance exacte trouvée pour '#{normalized_search}'")
        # 2. Pas de correspondance exacte, utiliser la correspondance fuzzy améliorée
        find_improved_fuzzy_match(search_term, normalized_search, candidates)

      artist ->
        # 3. Vérifier si le match exact est de faible qualité (popularité très basse)
        popularity = get_popularity(artist)
        Logger.info("🎯 EXACT: Match exact trouvé: '#{artist["name"]}' (ID: #{artist["id"]}) | Pop: #{popularity}")

        # Si l'artiste a une très faible popularité, chercher des alternatives phonétiques plus populaires
        if popularity <= 10 do
          Logger.info("🎯 🔍 ALTERNATIVE: Recherche d'alternatives plus populaires pour match exact de faible qualité")
          better_alternative = find_popular_phonetic_alternative(search_term, normalized_search, candidates, artist)

          case better_alternative do
            nil ->
              Logger.info("🎯 ✅ CONSERVÉ: Aucune alternative trouvée, conservation du match exact: '#{artist["name"]}'")
              artist

            alternative ->
              Logger.info("🎯 ✅ REMPLACÉ: Alternative plus populaire trouvée: '#{alternative["name"]}' (Pop: #{get_popularity(alternative)}) au lieu de '#{artist["name"]}' (Pop: #{popularity})")
              alternative
          end
        else
          Logger.info("🎯 ✅ VALIDÉ: Match exact avec bonne popularité: '#{artist["name"]}' (Pop: #{popularity})")
          artist
        end
    end
  end

  # Fonctions privées

  defp fetch_artists_from_spotify(artist_name, opts) do
    Logger.info("Searching Spotify for artist: #{artist_name}")

    query_params = %{
      q: artist_name,
      type: "artist",
      limit: 20  # Limite raisonnable pour éviter trop de résultats
    }

    path = "/search?" <> URI.encode_query(query_params)

    case HttpClient.get(path, opts) do
      {:ok, %{"artists" => %{"items" => items}}} ->
        Logger.info("Found #{length(items)} artists for '#{artist_name}'")
        {:ok, items}

      {:ok, response} ->
        Logger.warning("Unexpected Spotify search response: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        Logger.error("Spotify artist search failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_artist_by_id_from_spotify(artist_id, opts) do
    Logger.info("Fetching artist details for ID: #{artist_id}")

    path = "/artists/#{artist_id}"

    case HttpClient.get(path, opts) do
      {:ok, artist_data} ->
        Logger.info("Retrieved artist: #{artist_data["name"]}")
        {:ok, artist_data}

      {:error, {:http_error, 404, _}} ->
        Logger.warning("Artist not found: #{artist_id}")
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to fetch artist #{artist_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Fonction améliorée pour la correspondance fuzzy
  defp find_improved_fuzzy_match(original_search, normalized_search, candidates) do
    Logger.info("🔍 FUZZY START: Recherche fuzzy pour '#{original_search}' (normalisé: '#{normalized_search}')")

    # Calculer le score de similarité pour chaque candidat
    scored_candidates = Enum.map(candidates, fn artist ->
      normalized_candidate = normalize_artist_name(artist["name"])
      similarity_score = calculate_similarity(normalized_search, normalized_candidate)
      popularity = get_popularity(artist)

      # Score combiné amélioré : similarité (80%) + popularité (20%)
      combined_score = similarity_score * 0.8 + (popularity / 100.0) * 0.2

      Logger.info("🔍 SCORE: '#{artist["name"]}' → '#{normalized_candidate}' | Sim: #{Float.round(similarity_score, 3)} | Pop: #{popularity} | Score: #{Float.round(combined_score, 3)} | ID: #{artist["id"]}")

      {artist, similarity_score, popularity, combined_score}
    end)

    # Trier par score pour voir le classement
    sorted_candidates = Enum.sort_by(scored_candidates, &elem(&1, 3), :desc)

    Logger.info("🔍 RANKING: Top 3 candidats:")
    sorted_candidates
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.each(fn {{artist, sim, pop, score}, rank} ->
      Logger.info("🔍   #{rank}. '#{artist["name"]}' | Score: #{Float.round(score, 3)} | Sim: #{Float.round(sim, 3)} | Pop: #{pop}")
    end)

    # Logique de sélection améliorée
    case List.first(sorted_candidates) do
      {best_artist, similarity, _popularity, score} when similarity >= 0.7 ->
        Logger.info("🔍 ✅ SÉLECTIONNÉ (haute similarité ≥ 70%): '#{best_artist["name"]}' | Sim: #{Float.round(similarity, 3)} | Score: #{Float.round(score, 3)}")
        best_artist

      {best_artist, similarity, _popularity, score} when similarity >= 0.5 and score >= 0.6 ->
        Logger.info("🔍 ✅ SÉLECTIONNÉ (similarité modérée + bon score): '#{best_artist["name"]}' | Sim: #{Float.round(similarity, 3)} | Score: #{Float.round(score, 3)}")
        best_artist

      {fallback_artist, similarity, _popularity, _score} when similarity < 0.5 ->
        # Similarité trop faible - vérifier s'il y a un candidat vraiment proche
        better_match = find_close_phonetic_match(original_search, candidates)

        case better_match do
          nil ->
            Logger.warning("🔍 ⚠️  FALLBACK: Aucune bonne correspondance trouvée. Meilleur candidat: '#{fallback_artist["name"]}' (sim: #{Float.round(similarity, 3)}) - RISQUE DE MAUVAIS MATCH")
            nil

          match ->
            Logger.info("🔍 ✅ MATCH PHONÉTIQUE: Trouvé '#{match["name"]}' pour '#{original_search}'")
            match
        end

      nil ->
        Logger.info("🔍 ❌ Aucun candidat trouvé")
        nil

      {best_artist, similarity, _popularity, score} ->
        Logger.info("🔍 ✅ SÉLECTIONNÉ (par défaut): '#{best_artist["name"]}' | Sim: #{Float.round(similarity, 3)} | Score: #{Float.round(score, 3)}")
        best_artist
    end
  end

  # Fonction pour trouver des correspondances phonétiques proches (ex: sliman -> slimane)
  defp find_close_phonetic_match(original_search, candidates) do
    search_lower = String.downcase(original_search)

    # Rechercher des correspondances avec une différence minime de caractères
    Enum.find(candidates, fn artist ->
      artist_lower = String.downcase(artist["name"])
      is_close_phonetic_match(search_lower, artist_lower)
    end)
  end

  # Détermine si deux noms sont phonétiquement proches (ex: sliman/slimane)
  defp is_close_phonetic_match(search, candidate) do
    distance = levenshtein_distance(search, candidate)
    max_length = max(String.length(search), String.length(candidate))
    similarity = 1.0 - (distance / max_length)

    cond do
      distance <= 2 and similarity >= 0.85 ->
        Logger.info("🔍 📞 PHONÉTIQUE: '#{search}' ↔ '#{candidate}' | Distance: #{distance} | Sim: #{Float.round(similarity, 3)}")
        true

      String.contains?(candidate, search) and String.length(candidate) - String.length(search) <= 2 ->
        Logger.info("🔍 📞 PHONÉTIQUE (contient): '#{search}' dans '#{candidate}'")
        true

      String.contains?(search, candidate) and String.length(search) - String.length(candidate) <= 2 ->
        Logger.info("🔍 📞 PHONÉTIQUE (contenu dans): '#{candidate}' dans '#{search}'")
        true

      true ->
        false
    end
  end

  # Trouve une alternative phonétiquement proche mais plus populaire qu'un match exact de faible qualité
  defp find_popular_phonetic_alternative(original_search, _normalized_search, candidates, current_match) do
    current_popularity = get_popularity(current_match)
    search_lower = String.downcase(original_search)

    Logger.info("🔍 🎯 ALTERNATIVE SEARCH: Recherche alternative pour '#{original_search}' (match actuel: '#{current_match["name"]}', pop: #{current_popularity})")

    # Chercher des candidats phonétiquement proches avec une popularité significativement plus élevée
    phonetic_alternatives = Enum.filter(candidates, fn candidate ->
      candidate["id"] != current_match["id"] and  # Exclure le match actuel
      is_phonetic_alternative(search_lower, String.downcase(candidate["name"]), current_popularity)
    end)

    case phonetic_alternatives do
      [] ->
        Logger.info("🔍 🎯 ALTERNATIVE: Aucune alternative phonétique plus populaire trouvée")
        nil

      alternatives ->
        # Trier par popularité décroissante et prendre le plus populaire
        best_alternative = Enum.max_by(alternatives, &get_popularity/1)
        best_popularity = get_popularity(best_alternative)

        Logger.info("🔍 🎯 ALTERNATIVE: #{length(alternatives)} alternatives trouvées. Meilleure: '#{best_alternative["name"]}' (pop: #{best_popularity})")

        # Ne retourner l'alternative que si elle est significativement plus populaire
        if best_popularity >= current_popularity + 20 do
          Logger.info("🔍 ✅ ALTERNATIVE VALIDÉE: '#{best_alternative["name"]}' suffisamment plus populaire (+#{best_popularity - current_popularity})")
          best_alternative
        else
          Logger.info("🔍 ❌ ALTERNATIVE REJETÉE: Différence de popularité insuffisante (+#{best_popularity - current_popularity})")
          nil
        end
    end
  end

  # Détermine si un candidat est une alternative phonétique valide
  defp is_phonetic_alternative(search_lower, candidate_lower, _min_popularity_threshold) do
    # Vérifier la proximité phonétique
    is_phonetic = is_close_phonetic_match(search_lower, candidate_lower)

    if is_phonetic do
      Logger.info("🔍 📞 ÉVALUATION: '#{search_lower}' ↔ '#{candidate_lower}' | Phonétique: #{is_phonetic}")
    end

    is_phonetic
  end

  # Calcule la similarité entre deux chaînes normalisées
  defp calculate_similarity(str1, str2) do
    # 1. Correspondance exacte = 100%
    if str1 == str2, do: 1.0, else: calculate_fuzzy_similarity(str1, str2)
  end

  defp calculate_fuzzy_similarity(str1, str2) do
    # 2. Essayer en remplaçant underscores par espaces et vice versa
    str1_alt = String.replace(str1, "_", " ")
    str2_alt = String.replace(str2, "_", " ")

    # Logger.info("🔍 FUZZY DEBUG: '#{str1}' vs '#{str2}'")

    cond do
      str1 == str2_alt or str1_alt == str2 or str1_alt == str2_alt ->
        Logger.info("🔍 FUZZY: Correspondance underscore/espace → 0.95")
        0.95  # Très bonne correspondance (underscore/espace)

      # 3. Tester la similarité avec suppression d'accents
      remove_accents(str1) == remove_accents(str2) ->
        Logger.info("🔍 FUZZY: Correspondance accents → 0.90")
        0.90  # Bonne correspondance (accents différents)

      remove_accents(str1_alt) == remove_accents(str2_alt) ->
        Logger.info("🔍 FUZZY: Correspondance underscore + accents → 0.85")
        0.85  # Correspondance avec variation underscore + accents

      # 4. Tester la concaténation (jacquebrel = jacques brel)
      calculate_concatenation_similarity(str1, str2) > 0.0 ->
        concat_score = calculate_concatenation_similarity(str1, str2)
        Logger.info("🔍 FUZZY: Correspondance concaténation → #{concat_score}")
        concat_score

      true ->
        # 5. Calculer similarité basée sur les mots communs
        word_score = calculate_word_similarity(str1_alt, str2_alt)
        Logger.info("🔍 FUZZY: Correspondance mots communs → #{word_score}")
        word_score
    end
  end

  defp calculate_word_similarity(str1, str2) do
    words1 = String.split(str1, " ") |> Enum.reject(&(&1 == ""))
    words2 = String.split(str2, " ") |> Enum.reject(&(&1 == ""))

    if length(words1) == 0 or length(words2) == 0 do
      0.0
    else
      # Compter les mots en commun
      common_words = MapSet.intersection(MapSet.new(words1), MapSet.new(words2))
      total_words = max(length(words1), length(words2))

      MapSet.size(common_words) / total_words
    end
  end

  defp normalize_artist_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> remove_accents()                   # Supprimer les accents pour comparaison insensible
    |> String.replace(~r/[-_]+/, " ")     # Remplacer underscores ET traits d'union par espaces
    |> String.replace(~r/[^\w\s]/, "")    # Supprimer ponctuation (garder lettres, chiffres, espaces)
    |> String.replace(~r/\s+/, " ")       # Normaliser espaces multiples
    |> String.replace(~r/^the\s+/, "")    # Supprimer "the" au début
    |> String.trim()                      # Nettoyer les espaces en début/fin
  end

  defp normalize_artist_name(_), do: ""

  # Supprime les accents des caractères pour une comparaison insensible aux accents.
  # Utilise la normalisation Unicode NFD pour décomposer les caractères accentués.
  defp remove_accents(string) do
    string
    |> String.normalize(:nfd)           # Décompose les caractères (é → e + ´)
    |> String.replace(~r/[̀-ͯ]/, "")     # Supprime les accents combinés (range Unicode)
  end

  # Détecte les concaténations : jacquebrel = jacques brel
  defp calculate_concatenation_similarity(str1, str2) do
    # Supprimer espaces pour comparaison de concaténation
    str1_no_spaces = String.replace(str1, " ", "")
    str2_no_spaces = String.replace(str2, " ", "")

    # Logger.info("🔗 CONCAT DEBUG: '#{str1}' → '#{str1_no_spaces}' vs '#{str2}' → '#{str2_no_spaces}'")

    cond do
      # Correspondance exacte sans espaces
      str1_no_spaces == str2_no_spaces ->
        Logger.info("🔗 CONCAT: Correspondance exacte sans espaces → 0.88")
        0.88  # Très bonne correspondance de concaténation

      # Calculer similarité par distance de caractères
      calculate_string_similarity(str1_no_spaces, str2_no_spaces) >= 0.8 ->
        similarity = calculate_string_similarity(str1_no_spaces, str2_no_spaces)
        Logger.info("🔗 CONCAT: Similarité élevée entre '#{str1_no_spaces}' et '#{str2_no_spaces}' | Sim: #{similarity} → 0.82")
        0.82

      # str1 est une sous-chaîne de str2 sans espaces (ou vice versa)
      String.contains?(str2_no_spaces, str1_no_spaces) and String.length(str1_no_spaces) > 3 ->
        similarity = String.length(str1_no_spaces) / String.length(str2_no_spaces)
        Logger.info("🔗 CONCAT: '#{str1_no_spaces}' contenu dans '#{str2_no_spaces}' | Ratio: #{similarity}")
        if similarity > 0.7, do: 0.80, else: 0.0

      String.contains?(str1_no_spaces, str2_no_spaces) and String.length(str2_no_spaces) > 3 ->
        similarity = String.length(str2_no_spaces) / String.length(str1_no_spaces)
        Logger.info("🔗 CONCAT: '#{str2_no_spaces}' contenu dans '#{str1_no_spaces}' | Ratio: #{similarity}")
        if similarity > 0.7, do: 0.80, else: 0.0

      true ->
        Logger.info("🔗 CONCAT: Aucune correspondance de concaténation → 0.0")
        0.0
    end
  end

  # Calcule la distance de Levenshtein normalisée entre deux chaînes
  defp calculate_string_similarity(str1, str2) do
    if String.length(str1) == 0 and String.length(str2) == 0 do
      1.0  # Deux chaînes vides sont identiques
    else
      distance = levenshtein_distance(str1, str2)
      max_length = max(String.length(str1), String.length(str2))

      # Convertir la distance en similarité (1.0 = identique, 0.0 = très différent)
      similarity = 1.0 - (distance / max_length)

      # Logger.info("🔗 LEVENSHTEIN: '#{str1}' vs '#{str2}' | Distance: #{distance} | Max: #{max_length} | Sim: #{similarity}")

      similarity
    end
  end

  # Implémentation de l'algorithme de distance de Levenshtein
  defp levenshtein_distance(str1, str2) do
    chars1 = String.graphemes(str1)
    chars2 = String.graphemes(str2)

    len1 = length(chars1)
    len2 = length(chars2)

    # Créer une matrice pour la programmation dynamique
    matrix = initialize_matrix(len1, len2)

    # Calculer la distance
    calculate_levenshtein_matrix(chars1, chars2, matrix, len1, len2)
  end

  # Initialise la matrice pour l'algorithme de Levenshtein
  defp initialize_matrix(len1, len2) do
    # Créer une matrice (len1+1) x (len2+1)
    matrix = :array.new(len1 + 1, default: :array.new(len2 + 1, default: 0))

    # Initialiser la première ligne et colonne
    matrix = Enum.reduce(0..len1, matrix, fn i, acc ->
      :array.set(i, :array.set(0, i, :array.get(i, acc)), acc)
    end)

    Enum.reduce(0..len2, matrix, fn j, acc ->
      first_row = :array.get(0, acc)
      updated_row = :array.set(j, j, first_row)
      :array.set(0, updated_row, acc)
    end)
  end

  # Calcule la matrice de distance de Levenshtein
  defp calculate_levenshtein_matrix(chars1, chars2, matrix, len1, len2) do
    Enum.reduce(1..len1, matrix, fn i, matrix_acc ->
      Enum.reduce(1..len2, matrix_acc, fn j, inner_matrix ->
        char1 = Enum.at(chars1, i - 1)
        char2 = Enum.at(chars2, j - 1)

        cost = if char1 == char2, do: 0, else: 1

        # Récupérer les valeurs précédentes
        prev_row = :array.get(i - 1, inner_matrix)
        curr_row = :array.get(i, inner_matrix)

        deletion = :array.get(j, prev_row) + 1
        insertion = :array.get(j - 1, curr_row) + 1
        substitution = :array.get(j - 1, prev_row) + cost

        min_cost = min(deletion, min(insertion, substitution))

        # Mettre à jour la matrice
        updated_row = :array.set(j, min_cost, curr_row)
        :array.set(i, updated_row, inner_matrix)
      end)
    end)
    |> (fn final_matrix ->
      last_row = :array.get(len1, final_matrix)
      :array.get(len2, last_row)
    end).()
  end

  defp get_popularity(%{"popularity" => popularity}) when is_integer(popularity), do: popularity
  defp get_popularity(_), do: 0
end
