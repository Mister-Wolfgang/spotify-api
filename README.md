# 🎵 Spotify Albums API

API REST en Elixir/Phoenix pour récupérer les albums d'artistes via l'API Spotify avec rate limiting, cache et authentification automatique.

## 🚀 Fonctionnalités

- **Recherche d'artistes** : Trouve les artistes par nom avec gestion des ambiguïtés
- **Albums complets** : Récupère tous les albums d'un artiste avec pagination automatique
- **Tri intelligent** : Albums classés par date de sortie (plus récent en premier)
- **Cache performant** : Mise en cache avec TTL pour optimiser les performances
- **Rate limiting** : Protection contre les abus avec Token Bucket Algorithm
- **Gestion des erreurs** : Retry automatique et gestion des erreurs Spotify
- **Authentification** : Client Credentials Flow avec renouvellement automatique des tokens
- **Live reload** : Rechargement automatique en développement

## 📋 Prérequis

- **Elixir** 1.14+ et **Erlang/OTP** 25+
- **inotify-tools** (pour le live reload sur Linux)
- **Compte Spotify Developer** (gratuit)

## 🛠 Installation

### 1. Installer Erlang/OTP et Elixir

#### 🐧 Ubuntu/Debian :

```bash
# Méthode 1: Via les packages officiels (recommandé)
sudo apt update
sudo apt install erlang elixir

# Méthode 2: Via Erlang Solutions (versions plus récentes)
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt update
sudo apt install esl-erlang elixir

# Installer les dépendances de développement
sudo apt install erlang-dev erlang-xmerl build-essential

# Installer inotify-tools pour le live reload
sudo apt install -y inotify-tools

# Vérifier les installations
erl -version
elixir --version
```

#### 🍎 macOS :

```bash
# Méthode 1: Avec Homebrew (recommandé)
brew install erlang elixir

# Méthode 2: Avec MacPorts
sudo port install erlang +universal
sudo port install elixir

# Méthode 3: Avec asdf (gestionnaire de versions)
brew install asdf
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang latest
asdf install elixir latest
asdf global erlang latest
asdf global elixir latest

# Vérifier les installations
erl -version
elixir --version
```

#### 🪟 Windows :

```bash
# Méthode 1: Avec Chocolatey (recommandé)
# Installer Chocolatey d'abord: https://chocolatey.org/install
choco install erlang elixir

# Méthode 2: Avec Scoop
scoop install erlang elixir

# Méthode 3: Installation manuelle
# 1. Télécharger Erlang/OTP depuis: https://www.erlang.org/downloads
# 2. Télécharger Elixir depuis: https://elixir-lang.org/install.html#windows

# Vérifier les installations (dans PowerShell/CMD)
erl -version
elixir --version
```

#### 🐧 CentOS/RHEL/Fedora :

```bash
# CentOS/RHEL avec EPEL
sudo yum install epel-release
sudo yum install erlang elixir

# Fedora
sudo dnf install erlang elixir

# Ou via Erlang Solutions
curl -O https://packages.erlang-solutions.com/erlang-solutions-2.0-1.noarch.rpm
sudo rpm -Uvh erlang-solutions-2.0-1.noarch.rpm
sudo yum install esl-erlang elixir
```

#### 🐧 Arch Linux :

```bash
# Via pacman
sudo pacman -S erlang elixir

# Via AUR (versions de développement)
yay -S erlang-git elixir-git
```

#### 🐳 Docker (toutes plateformes) :

```bash
# Utiliser l'image officielle Elixir
docker run -it --rm elixir:latest

# Ou créer un Dockerfile
FROM elixir:1.15-alpine
WORKDIR /app
COPY . .
RUN mix deps.get
CMD ["mix", "phx.server"]
```

#### ⚙️ Gestionnaire de versions asdf (recommandé pour le développement) :

```bash
# Installer asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

# Ajouter à votre shell (.bashrc, .zshrc, etc.)
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# Redémarrer le terminal et installer les plugins
asdf plugin add erlang
asdf plugin add elixir

# Installer les versions spécifiques
asdf install erlang 26.2.1
asdf install elixir 1.15.7-otp-26

# Définir les versions globales
asdf global erlang 26.2.1
asdf global elixir 1.15.7-otp-26
```

### 2. Cloner et configurer le projet

```bash
# Cloner le repository
git clone https://github.com/votre-username/spotify-api.git
cd spotify-api

# Installer les dépendances
mix deps.get

# Compiler le projet
mix compile
```

### 3. Configuration Spotify

#### Créer une application Spotify :

1. Aller sur [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/applications)
2. Cliquer sur "Create an App"
3. Remplir les informations (nom, description)
4. Noter le **Client ID** et **Client Secret**

#### Configurer les credentials :

```bash
# Copier le fichier d'environnement
cp .env.example .env

# Éditer le fichier .env avec vos credentials
nano .env
```

Contenu du fichier `.env` :

```bash
# Spotify API Credentials
SPOTIFY_CLIENT_ID=votre_client_id_ici
SPOTIFY_CLIENT_SECRET=votre_client_secret_ici
```

### 4. Lancer l'application

#### Mode développement (avec live reload) :

```bash
# Démarrer le serveur Phoenix
mix phx.server

# L'application sera disponible sur http://localhost:4000
```

#### Mode production :

```bash
# Compiler pour la production
MIX_ENV=prod mix compile

# Démarrer en mode production
MIX_ENV=prod mix phx.server
```

## 🧪 Tests

### Lancer tous les tests :

```bash
# Tests complets
mix test

# Tests avec détails
mix test --trace

# Tests avec couverture
mix test --cover
```

### Tests spécifiques :

```bash
# Tests du RateLimiter
mix test test/spotify_api/rate_limiter_test.exs

# Tests du HttpClient
mix test test/spotify_api/spotify/http_client_test.exs

# Tests d'un module spécifique
mix test test/spotify_api/features/artist_albums/
```

## 🔧 Dépannage

### Problème : "inotify-tools is needed"

```bash
# Sur Ubuntu/Debian
sudo apt install -y inotify-tools

# Redémarrer le serveur
mix phx.server
```

### Problème : "Port 4000 already in use"

```bash
# Tuer le processus utilisant le port
lsof -ti:4000 | xargs kill -9

# Ou utiliser un autre port
PORT=4001 mix phx.server
```

### Problème : "invalid_client" Spotify

1. Vérifier que les credentials dans `.env` sont corrects
2. S'assurer que l'application Spotify est active
3. Vérifier que les variables d'environnement sont chargées

### Problème : Tests qui échouent

```bash
# Nettoyer et recompiler
mix clean
mix deps.get
mix compile

# Relancer les tests
mix test
```

### Exemples d’erreurs API

- **401 Unauthorized** : Token expiré ou credentials invalides.  
  Solution : Vérifier `.env`, relancer le serveur.
- **429 Too Many Requests** : Limite de requêtes atteinte.  
  Solution : Attendre le délai indiqué dans la réponse.
- **400 Bad Request** : Paramètre manquant ou incorrect.  
  Solution : Vérifier l’URL et les paramètres envoyés.

## 📚 Utilisation de l'API

### Endpoints disponibles :

#### Rechercher les albums d'un artiste :

```bash
GET /api/v1/artists/{artist_name}/albums

# Exemple
curl "http://localhost:4000/api/v1/artists/Radiohead/albums"
```

#### Réponse JSON :

```json
{
  "artist": "Radiohead",
  "albums": [
    {
      "name": "A Moon Shaped Pool",
      "release_date": "2016-05-08",
      "total_tracks": 11,
      "spotify_url": "https://open.spotify.com/album/...",
      "images": [...]
    }
  ],
  "total": 15,
  "cached": false
}
```

## 🏗 Architecture

```
lib/
├── spotify_api/
│   ├── application.ex          # Supervision tree
│   ├── rate_limiter.ex         # Token bucket rate limiting
│   ├── cache/                  # Cache management
│   ├── spotify/
│   │   ├── auth_manager.ex     # Spotify authentication
│   │   └── http_client.ex      # HTTP client with retry
│   └── features/
│       └── artist_albums/      # Business logic
└── spotify_api_web/
    ├── endpoint.ex             # Phoenix endpoint
    ├── router.ex               # Routes
    └── controllers/            # API controllers
```

## 📈 Schéma visuel

```
[Client] → [Phoenix Router] → [Controller] → [Business Logic] → [Spotify API]
                                 ↓
                              [Cache]
                                 ↓
                           [Rate Limiter]
```

## 🧩 Extensions & Avancés

- **Ajouter un endpoint** : Créer un contrôleur dans `lib/spotify_api_web/controllers/`, ajouter la route dans `router.ex`.
- **Ajouter un worker** : Créer le module dans `lib/spotify_api/workers/`, ajouter au supervision tree dans `application.ex`.
- **Ajouter une stratégie de cache** : Créer dans `lib/spotify_api/cache/strategies.ex`, référencer dans le cache principal.

### Cas d’usage avancés

- **Pagination** : Utiliser les paramètres `limit` et `offset` dans l’URL.
- **Filtrage** : Ajouter des paramètres de requête pour filtrer par année, type d’album, etc.
- **Monitoring** : Utiliser le module `performance/metrics.ex` pour exporter des métriques.

## 🚀 Déploiement

### Docker (recommandé) :

```bash
# Construire l'image
docker build -t spotify-api .

# Lancer le container
docker run -p 4000:4000 --env-file .env spotify-api
```

### Déploiement manuel :

```bash
# Préparer la release
MIX_ENV=prod mix release

# Lancer la release
_build/prod/rel/spotify_api/bin/spotify_api start
```

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/nouvelle-fonctionnalite`)
3. Commit les changes (`git commit -am 'Ajouter nouvelle fonctionnalité'`)
4. Push vers la branche (`git push origin feature/nouvelle-fonctionnalite`)
5. Créer une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🔗 Liens utiles

- [Documentation Elixir](https://elixir-lang.org/docs.html)
- [Documentation Phoenix](https://hexdocs.pm/phoenix/)
- [API Spotify](https://developer.spotify.com/documentation/web-api/)
- [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/)

## Endpoint API Phoenix

### Récupérer les albums d’un artiste

- **URL** : `/api/v1/artists/:name/albums`
- **Méthode** : `GET`
- **Paramètres** :
  - `name` (string, requis) : Nom de l’artiste (ex : Radiohead)
  - `album_types` (string, optionnel) : Types d’albums à inclure (ex : album,single)
  - `limit` (integer, optionnel) : Nombre maximum d’albums à retourner (1-200)

#### Exemple de requête

```bash
curl -X GET "http://localhost:4000/api/v1/artists/Radiohead/albums"
```

#### Exemple de réponse

```json
{
  "albums": [
    {
      "id": "6ofEQubaL265rIW6WnCU8y",
      "name": "KID A MNESIA",
      "album_type": "album",
      "external_urls": {
        "spotify": "https://open.spotify.com/album/6ofEQubaL265rIW6WnCU8y"
      },
      "images": [
        {
          "width": 640,
          "url": "https://i.scdn.co/image/ab67616d0000b273bbaaa8bf9aedb07135d2c6d3",
          "height": 640
        }
      ],
      "release_date": "2021-11-05",
      "total_tracks": 34
    }
    // ...
  ],
  "artist": "Radiohead",
  "total_albums": 44
}
```
