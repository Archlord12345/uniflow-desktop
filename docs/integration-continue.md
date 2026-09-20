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
| `qualite` | ubuntu | Flutter **3.47.1** épinglé (`subosito/flutter-action`, cache), `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --coverage`. Artefact : `couverture-lcov` (`coverage/lcov.info`). |
| `build-linux` | ubuntu, `needs: qualite` | Dépendances apt (clang, cmake, ninja, gtk3, liblzma, libstdc++-12, **libwebkit2gtk-4.1**, **libpulse-dev**), `.env` depuis les secrets, `flutter build linux --release`. Artefact : `uniflow-desktop-linux-x64.tar.gz`. |
| `build-windows` | windows, `needs: qualite` | `flutter build windows --release`. Artefact : `uniflow-desktop-windows-x64.zip`. |
| `build-android-tablet` | ubuntu, `needs: qualite` | JDK 21 (zulu), `flutter build apk --release`. Artefact : `uniflow-desktop-tablette.apk`. |
| `release` | ubuntu, `needs` des trois builds, **tag `v*` seulement** | GitHub Release (`softprops/action-gh-release@v2`) avec les trois archives et des notes générées. |

Pourquoi ces dépendances Linux :

- `libwebkit2gtk-4.1-dev` : exigé par `desktop_webview_window`, tiré par
  `flutter_web_auth_2`, lui-même tiré par le SDK Appwrite. Sans lui CMake
  échoue sur `pkg_check_modules(webkit2gtk-4.0)`.
- `libpulse-dev` : le plugin `flutter_webrtc` (visioconférence embarquée) lie
  PulseAudio quand il le trouve ; sans les en-têtes, l'édition de liens échoue.

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
