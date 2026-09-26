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

Concrètement, « Créer une réunion » :

1. choisit l'adresse LAN du poste (cartes physiques avant ponts Docker, VPN et
   machines virtuelles ; bouclage et lien-local écartés — `conference_network.dart`) ;
2. lance `livekit-server` et l'API de jonction sur des ports libres ;
3. ouvre **la salle dans l'application** (`conference_room_screen.dart`,
   `livekit_client`) : vidéo, micro, caméra, partage d'écran, épinglage,
   participants, et un panneau d'invitation avec QR ;
4. sert aux participants sans application une **page navigateur**
   `http://<IP du poste>:<port>/join/<CODE>` (bundle `livekit-client` embarqué
   dans `assets/conference_web/`). En `http://`, les navigateurs refusent micro
   et caméra : la page l'explique et bascule en mode écoute ; l'application de
   bureau, elle, n'a pas cette limite.

Un autre poste rejoint par « Rejoindre une réunion » (adresse ou lien collé +
code) ou depuis l'annuaire ; il obtient son jeton directement auprès de
l'hôte (`GET /rooms/by-code/<CODE>` puis `GET /rooms/<id>/join?code=…`).

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

- **Linux : `libpulse-dev`** (le plugin `flutter_webrtc` lie PulseAudio). Si le
  build échoue sur `libwebrtc directory does not exist after extraction` ou
  `'libwebrtc.h' file not found`, l'archive libwebrtc du cache pub est
  tronquée : voir `docs/depannage.md`.

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
aux différentes largeurs (`layout_test.dart`), la page Équipe et le logo, et
la visioconférence sans serveur média (`conference_join_test.dart`,
`conference_host_attendance_test.dart`).

`test_live/` n'est pas lancé par `flutter test` : il exige le vrai
`livekit-server` installé et vérifie de bout en bout ce que fait « Créer une
réunion » puis « Rejoindre » — jusqu'à la validation du jeton par le serveur
média (`GET /rtc/validate`) et la page navigateur servie à l'adresse LAN :

```bash
flutter test test_live/conference_host_live_test.dart
```

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
- `docs/integration-continue.md` — le workflow GitHub Actions (`ci.yml`) : qualité → builds Linux / Windows / Android → release.
- `docs/depannage.md` — symptômes connus et réparations (archive libwebrtc tronquée, webkit2gtk, verrou Flutter…).
- À la racine de l'espace de travail : `ETAT-DU-PROJET.md` et `TRAVAUX-RESTANTS.md`.
# Nettoyer
flutter clean

# Récupérer les dépendances
flutter pub get

# Générer le build Linux Release
flutter build linux --release

# Générer le paquet DEB avec Fastforge
fastforge package --platform=linux --targets=deb

