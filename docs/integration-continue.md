# Intégration continue — `.github/workflows/ci.yml`

Un seul workflow, « UniFlow Desktop », découpé en jobs chaînés. L'ancien
`build.yml` (trois builds indépendants, sans tests) a été remplacé le
2026-09-20 : il construisait des binaires même quand `flutter analyze`
échouait, et complétait le `.env` versionné au lieu de le remplacer.

## Déclencheurs

- `push` sur `main` et `feature/frontend-uniflow-app` (et sur les tags `v*`) ;
- `pull_request` vers `main` ;
- `workflow_dispatch` (lancement manuel).

`concurrency` : un nouveau push sur la même branche annule le run précédent.

## Jobs

| Job | Machine | Rôle |
|---|---|---|
| `qualite` | ubuntu | Flutter **3.47.1** épinglé (`subosito/flutter-action`, cache), `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --coverage`. Aucun artefact : la couverture sert aux tests, pas à la distribution, et chaque artefact consomme le quota de stockage des Actions. |
| `build-linux` | ubuntu, `needs: qualite` | Dépendances apt (clang, cmake, ninja, gtk3, liblzma, libstdc++-12, **libwebkit2gtk-4.1**, **libpulse-dev**), `.env` depuis les secrets, `flutter build linux --release`. Artefact : `uniflow-desktop-linux-x64.tar.gz`. |
| `build-windows` | **windows-latest**, `needs: qualite` | `choco install innosetup`, puis `flutter_distributor package --platform windows --targets exe --skip-clean` (l'outil lance `flutter build windows` lui-même, engendre un script Inno Setup depuis `windows/packaging/exe/make_config.yaml`, appelle `ISCC.exe` et vérifie que le paquet est sorti). Artefact : `dist/<version>/uniflow-<version>-windows-setup.exe` — un installateur, **pas une archive** : le Store et winget n'acceptent qu'un programme d'installation capable de se poser en silence. Le job installe cet `.exe` sur la machine de build (`/VERYSILENT` + `/DIR=` d'un dossier temporaire), vérifie le binaire et la clé `HKCU:\…\Uninstall\codes.kernelforge.uniflow_is1`, le désinstalle, puis publie taille, `InstallerSha256` et commutateurs dans le résumé du run. |
| `build-android-tablet` | ubuntu, `needs: qualite` | JDK 21 (zulu), `flutter build apk --release`. Artefact : `uniflow-desktop-tablette.apk`. |
| `release` | ubuntu, `needs` des trois builds, **tag `v*` seulement** | GitHub Release (`softprops/action-gh-release@v2`) avec le bundle Linux, l'installateur Windows et l'APK, plus des notes générées. |

Les trois artefacts de build sont purgés automatiquement au bout de
**3 jours** (`retention-days: 3`) : le quota de stockage d'un plan privé est de
500 Mo et 99 artefacts pesant 2,4 Go l'avaient atteint — depuis,
`upload-artifact` échouait sur `Failed to CreateArtifact` et le `release` ne
recevait plus rien. Mesuré avec
`gh api repos/KERNEL-FORGE-G/uniflow-desktop/actions/artifacts`. Ce qui doit
survivre à un run passe par la GitHub Release, pas par le magasin d'artefacts.

Pourquoi ces dépendances Linux :

- `libwebkit2gtk-4.1-dev` : exigé par `desktop_webview_window`, tiré par
  `flutter_web_auth_2`, lui-même tiré par le SDK Appwrite. Sans lui CMake
  échoue sur `pkg_check_modules(webkit2gtk-4.0)`.
- `libpulse-dev` : le plugin `flutter_webrtc` (visioconférence embarquée) lie
  PulseAudio quand il le trouve ; sans les en-têtes, l'édition de liens échoue.

## Paqueter une cible depuis son poste

Le même outil pilote la CI et le poste de développement : `flutter_distributor`
(épinglé en **0.6.10** dans le job Windows — c'est la version dont les sources
ont été lues, une montée de version doit être délibérée).

```bash
dart pub global activate flutter_distributor 0.6.10

# Windows, sur un poste Windows : sort dist/1.0.0+1/uniflow-1.0.0+1-windows-setup.exe
flutter_distributor --no-version-check package --platform windows --targets exe --skip-clean
```

`--skip-clean` évite un `flutter clean` complet ; l'outil lance tout de même
`flutter build windows` avant d'appeler `ISCC.exe`. Deux pièces de configuration
seulement : `distribute_options.yaml` (racine, dossier de sortie et jobs de
publication) et `windows/packaging/exe/make_config.yaml` (le contenu de
l'installateur). L'emplacement `<plateforme>/packaging/<cible>/make_config.yaml`
est imposé par le packager, pas par nous.

Trois pièges relevés dans les sources, à connaître avant de conclure qu'un
artefact existe :

- **Le maker `exe` n'existe que sur Windows** (`isSupportedOnCurrentPlatform`).
  Lancée sur Linux, la commande affiche `Warning: AppBuilderWindows is not
  supported on the current platform` et **sort en code 0 sans produire de
  fichier**. Le job Windows vérifie donc la présence réelle du `.exe` au lieu de
  se fier au code de retour.
- Le paquet est rangé dans `dist/<version>/`, pas à la racine de `dist/` : tout
  motif de recherche doit descendre d'un niveau.
- `pubspec.yaml` fournit le nom et la version : `uniflow` + `1.0.0+1` donnent
  `uniflow-1.0.0+1-windows-setup.exe`. Le `+` est un caractère valide dans un
  chemin Windows, mais il interdit de déduire la version du nom du fichier par
  une simple découpe.

## Secrets attendus

`APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_DATABASE_ID`,
`APPWRITE_STORAGE_BUCKET_ID`, `APPWRITE_API_FUNCTION_ID` — valeurs Appwrite
Cloud (`https://fra.cloud.appwrite.io/v1`, `uniflow`, `uniflow`,
`uniflow_assets`, `uniflow-api`). Le script `.github/scripts/write-env.sh`
**réécrit** `.env` à partir de ces secrets et arrête le build si l'un manque :
un binaire construit avec un `.env` incomplet pointerait sur un serveur mort.

Ces valeurs sont publiques (elles sont embarquées dans le binaire) ; aucune
clé serveur ne doit jamais y figurer.

## Publier une version

```bash
git tag v1.2.0 && git push origin v1.2.0
```

Le job `release` attend les trois builds puis publie la Release avec les
archives.

## Suivre un run

```bash
gh run list --workflow ci.yml --limit 5
gh run watch            # suit le run en cours jusqu'à sa fin
gh run view <id> --log-failed
```
