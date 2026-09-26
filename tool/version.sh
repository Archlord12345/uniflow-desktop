#!/usr/bin/env bash
# Version canonique d'UniFlow Desktop : la source de vérité unique des paquets.
#
# `pubspec.yaml` porte `MAJOR.MINOR.PATCH+BUILD`. Le tag Git, lui, porte
# `vMAJOR.MINOR.PATCH`. Ce script dérive les cinq formats de version exigés par
# dpkg, snapcraft, RPM, AUR et MSIX, et refuse de produire quoi que ce soit si
# le tag et le pubspec divergent — un paquet dont le numéro ne correspond pas au
# tag publié est inutilisable pour un rétroportage (NdT: backport).
#
# Utilisation :
#   eval "$(bash tool/version.sh)"          # définit VERSION_* dans l'environnement
#   bash tool/version.sh --check v1.0.0     # vérifie un tag, n'imprime rien
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

PUBSPEC_VERSION="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$/\1 \2/p' pubspec.yaml)"
if [ -z "$PUBSPEC_VERSION" ]; then
  echo "pubspec.yaml : version illisible, attendu « version: X.Y.Z+N »" >&2
  exit 1
fi
read -r SEMVER BUILD <<<"$PUBSPEC_VERSION"

# --check v1.0.0 : le tag doit porter le même X.Y.Z que le pubspec.
if [ "${1:-}" = "--check" ]; then
  TAG="${2:?tag attendu, ex. --check v1.0.0}"
  [ "${TAG#v}" = "$SEMVER" ] || {
    echo "Tag $TAG ≠ pubspec $SEMVER+$BUILD : corrige pubspec.yaml avant de taguer." >&2
    exit 1
  }
  exit 0
fi

# Dérivations. Chacune a sa grammaire, et un seul format ne convient pas aux
# quatre gestionnaires de paquets :
#   dpkg     `1.0.0+1`   — « + » est légal et trie après « 1.0.0 »
#   snapcraft `1.0.0+1`  — idem, l'espace est interdit
#   RPM      `1.0.0` - `1` — « + » est légal mais casse les comparaisons par
#                           `yum versioncompare` ; on bascule le build en Release
#   AUR      `1.0.0` - `1` — `pkgver` interdit « + »
#   MSIX     `1.0.0.1`   — quatre segments obligatoires, « + » interdit
echo "VERSION=$SEMVER"
echo "VERSION_BUILD=$BUILD"
echo "VERSION_DEB=${SEMVER}+${BUILD}"
echo "VERSION_RPM=$SEMVER"
echo "VERSION_RPM_RELEASE=$BUILD"
echo "VERSION_AUR=$SEMVER"
echo "VERSION_MSIX=${SEMVER}.${BUILD}"
echo "VERSION_SNAP=${SEMVER}+${BUILD}"
