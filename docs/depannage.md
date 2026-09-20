# Dépannage

Symptômes rencontrés sur les postes de développement, leur cause réelle et la
réparation. Chaque entrée cite le message observé pour être retrouvable.

## Linux : `libwebrtc directory does not exist after extraction`

Observé le 2026-09-20 avec `flutter run -d linux` :

```
libwebrtc directory does not exist after extraction
cmake -E tar: ZIP decompression failed (-5)
fatal error: 'libwebrtc.h' file not found
```

**Cause.** Le plugin `flutter_webrtc` télécharge une fois l'archive
`~/.pub-cache/hosted/pub.dev/flutter_webrtc-<version>/third_party/downloads/libwebrtc-linux-x64-release.zip`
(≈ 9,25 Mo). Une coupure réseau l'avait tronquée (8,7 Mo). Le CMake du plugin
**ne revérifie jamais une archive déjà présente** : chaque build retentait
l'extraction du même fichier corrompu et échouait au même endroit.

**Réparation** — supprimer l'archive et relancer le build, qui la retélécharge :

```bash
rm ~/.pub-cache/hosted/pub.dev/flutter_webrtc-*/third_party/downloads/libwebrtc-linux-x64-release.zip
flutter build linux --debug
```

Sur un réseau lent, reprendre le téléchargement à la main avant de relancer
(`-C -` reprend là où il s'est arrêté) :

```bash
cd ~/.pub-cache/hosted/pub.dev/flutter_webrtc-*/third_party/downloads
curl -L -C - -o libwebrtc-linux-x64-release.zip \
  https://github.com/webrtc-sdk/libwebrtc/releases/download/libwebrtc.m150.7871.02/libwebrtc-linux-x64-release.zip
cd .. && rm -rf libwebrtc && mkdir libwebrtc && unzip -q downloads/libwebrtc-linux-x64-release.zip -d libwebrtc
```

(`include/` et `lib/` doivent se retrouver dans `third_party/libwebrtc/`.)
Vérifier la taille avant d'extraire : `ls -l downloads/` doit afficher
≈ 9 250 000 octets.

## Linux : `pkg_check_modules(webkit2gtk-4.0)` échoue

`libwebkit2gtk-4.1-dev` manque (chaîne `appwrite` → `flutter_web_auth_2` →
`desktop_webview_window`). Sur Ubuntu 24.04 seul le paquet `4.1` existe :

```bash
sudo apt install -y libwebkit2gtk-4.1-dev
```

## Linux : `file INSTALL cannot copy ... /usr/local/uniflow_app`

`CMakeCache.txt` périmé : `flutter clean` puis relancer le build.

## Linux : édition de liens échoue sur `pulse`

Le plugin `flutter_webrtc` lie PulseAudio quand il détecte ses en-têtes ;
installer `libpulse-dev` (la CI le fait).

## Tests : `Waiting for another flutter command to release the startup lock`

Un `flutter test` précédent n'a pas rendu la main (session interrompue).
Identifier le processus (`ps aux | grep flutter_tools.snapshot`), vérifier son
répertoire (`ls -l /proc/<pid>/cwd`) et le tuer s'il appartient bien à ce
dépôt.

## Tests unitaires : `MissingPluginException … path_provider`

Le client Appwrite interroge `path_provider` à sa construction (jar de
cookies). Dans un `test()` nu, doubler le canal :

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
  const MethodChannel('plugins.flutter.io/path_provider'),
  (call) async => Directory.systemTemp.path,
);
```

(voir `test/session_flow_test.dart`).
