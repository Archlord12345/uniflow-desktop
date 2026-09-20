# UniFlow Desktop

Poste de travail d'UniFlow pour l'administration, les enseignants et les
délégués : gestion des étudiants, enseignants, programmes, unités
d'enseignement, salles et emplois du temps, messagerie, statistiques et
**visioconférence embarquée capable de fonctionner sans internet**. Écrit en
Flutter pour Linux, Windows, macOS et tablette Android ; il parle directement
à Appwrite Cloud, comme le web et le mobile.

## Sommaire

1. [Fonctionnalités](#fonctionnalités)
2. [Visioconférence embarquée](#visioconférence-embarquée)
3. [Prérequis](#prérequis)
4. [Installation et lancement](#installation-et-lancement)
5. [Configuration](#configuration)
6. [Tests](#tests)
7. [Organisation du dépôt](#organisation-du-dépôt)
8. [Documentation](#documentation)

## Fonctionnalités

| Module | Contenu |
| --- | --- |
| Connexion | Compte universitaire ou indépendant ; rôle lu dans la collection `users`, destinations et périmètres de visibilité déduits du rôle (`lib/models/user_role.dart`, `visibility_scope.dart`) |
| Tableau de bord | Indicateurs par rôle : effectifs, présences, devoirs, messages |
| Administration | Étudiants, enseignants, programmes, unités d'enseignement, salles, emploi du temps, équipe KERNEL FORGE — création, modification, suppression |
| Pédagogie | Devoirs, notes, présence |
| Communication | Messagerie (via la Function `uniflow-api`, chemin `/messaging`) |
| Statistiques | Assiduité, réussite, flux de présence |
| Visioconférence | Salles hébergées par le poste lui-même, voir ci-dessous |

## Visioconférence embarquée

Le desktop embarque son propre serveur de visioconférence : il pilote un
processus `livekit-server` local (`lib/services/conference/`), génère les
jetons d'accès lui-même (HMAC-SHA256) et publie la salle sur le réseau local.
Les participants — autres postes, mobiles — rejoignent la salle par l'adresse
IP du poste hôte, **sans passer par internet**. Appwrite ne sert qu'à
l'annuaire des réunions (collection `conference_rooms`) quand une connexion
existe ; sans connexion, la salle reste utilisable sur le réseau local.

Le binaire `livekit-server` est cherché dans `LIVEKIT_SERVER_PATH` (`.env`),
puis dans `~/.local/bin`, `~/bin`, `/usr/local/bin`, `/usr/bin`,
`/opt/livekit` et `C:\Program Files\LiveKit`. Installation :

```bash
curl -sSL https://get.livekit.io | bash        # Linux / macOS
```

## Prérequis

- Flutter stable (Dart ≥ 3.0).
- **Java 21** pour la cible tablette Android (Gradle 9.1 / AGP 9.0.1) :

  ```bash
  flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64
  ```

- **Linux : `libwebkit2gtk-4.1-dev`** (chaîne `appwrite` → `flutter_web_auth_2`
  → `desktop_webview_window`). Sur Ubuntu 24.04 seul le paquet `4.1` existe ;
  si CMake réclame `webkit2gtk-4.0`, c'est que `4.1` manque aussi :

  ```bash
  sudo apt install -y libwebkit2gtk-4.1-dev
  ```

  Si le build échoue ensuite sur `file INSTALL cannot copy ... /usr/local/uniflow_app`,
  le `CMakeCache.txt` est périmé : `flutter clean` puis relancer.

## Installation et lancement

```bash
flutter pub get
flutter run -d linux            # ou windows, macos
flutter build linux --release   # build/linux/x64/release/bundle/
flutter build apk --release     # tablette
```

Trois workflows GitHub Actions (`.github/workflows/build.yml`) produisent
l'exécutable Windows, les paquets Linux et l'APK tablette.

## Configuration

`.env` est déclaré comme asset et embarqué en clair : valeurs publiques
uniquement, jamais de clé serveur.

```env
APPWRITE_ENDPOINT=https://fra.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=uniflow
APPWRITE_DATABASE_ID=uniflow
APPWRITE_STORAGE_BUCKET_ID=uniflow_assets
APPWRITE_AVATAR_BUCKET_ID=uniflow_assets
APPWRITE_CHAT_FILES_BUCKET_ID=uniflow_assets
APPWRITE_API_FUNCTION_ID=uniflow-api
# LIVEKIT_SERVER_PATH=/usr/local/bin/livekit-server
# APPWRITE_CONFERENCE_COLLECTION_ID=conference_rooms
```

## Tests

```bash
flutter analyze
flutter test
```

Les tests couvrent le modèle de rôles (`user_role_test.dart`), la mise en page
aux différentes largeurs (`layout_test.dart`), la page Équipe et le logo.

## Organisation du dépôt

```
uniflow-desktop/
├── lib/
│   ├── models/                 rôles, destinations, périmètres, entités
│   ├── repositories/           accès Appwrite (académique, devoirs, messagerie, équipe, personnel)
│   ├── providers/              état (session, annuaire, programmes, planning, conférence, analyses)
│   ├── services/
│   │   ├── appwrite_service.dart
│   │   └── conference/         serveur LiveKit local, jetons, découverte réseau, registre des salles
│   ├── router/                 gardes par rôle
│   ├── screens/                un fichier par écran, main_shell.dart pour la barre latérale
│   ├── widgets/, theme/
├── test/
├── linux/  windows/  macos/  android/  ios/  web/
├── tools/                      génération des icônes
├── assets/brand/  assets/images/
└── docs/
```

## Documentation

- `docs/ADR-001-architecture-desktop.md` — décision d'architecture (couches, shell, contrat de chargement).
- `docs/README-LIVRAISON.md` — première livraison et correspondance avec le cahier des charges.
- À la racine de l'espace de travail : `ETAT-DU-PROJET.md` et `TRAVAUX-RESTANTS.md`.
