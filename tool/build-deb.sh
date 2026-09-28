#!/usr/bin/env bash
# Construit le paquet Debian d'UniFlow Desktop depuis un bundle Flutter déjà compilé.
#
# Ce script ne compile rien : il emballe `build/linux/x64/release/bundle`, produit
# par `flutter build linux --release`. Séparer les deux permet de relancer le
# packaging sans rejouer trois minutes de CMake, et de construire le .deb sur la
# même machine qui vient de produire le binaire testé à la main.
#
# Mise en page du paquet :
#   /opt/uniflow_app/          bundle complet, bibliothèques privées comprises
#   /usr/bin/uniflow           wrapper, seul fichier déposé hors de /opt
#   /usr/share/applications/   uniflow.desktop
#   /usr/share/icons/hicolor/  codes.kernelforge.uniflow.png, toutes tailles
#   /usr/share/metainfo/       dépôt AppStream lu par GNOME Software
#
# Le bundle n'est jamais éclaté dans /usr/lib : deux UniFlow installés par des
# voies différentes (APT, AUR, AppImage) ne peuvent pas se marcher dessus.
#
# Usage :
#   tool/build-deb.sh                                  # bundle par défaut -> dist/deb
#   tool/build-deb.sh --bundle chemin --output dossier
#   tool/build-deb.sh --skip-deps-check                # ne PAS utiliser en CI
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT"

BUNDLE="build/linux/x64/release/bundle"
OUTPUT="dist/deb"
CHECK_DEPS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle) BUNDLE="${2:?--bundle attend un chemin}"; shift 2 ;;
    --output|-o) OUTPUT="${2:?--output attend un chemin}"; shift 2 ;;
    --skip-deps-check) CHECK_DEPS=0; shift ;;
    -h|--help) sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Argument inconnu : %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -d "$BUNDLE" ] || {
  printf 'Bundle introuvable : %s\nlance `flutter build linux --release`.\n' "$BUNDLE" >&2
  exit 1
}
RUNNER="$BUNDLE/uniflow_app"
[ -f "$RUNNER" ] || { printf 'Binaire du runner absent : %s\n' "$RUNNER" >&2; exit 1; }

eval "$(bash tool/version.sh)"
# shellcheck disable=SC1091
. packaging/common/dependencies.env

# L'architecture se lit dans l'ELF, pas dans `uname -m` : un bundle croisé pour
# arm64 doit donner un paquet `arm64` même s'il est empaqueté sur une machine
# x86_64. Un paquet dont le champ Architecture ment s'installe mais ne démarre
# pas, et dpkg ne s'en plaint qu'au moment de la configuration.
case "$(readelf -h "$RUNNER" | sed -n 's/^ *Machine:  *//p')" in
  *X86-64*) ARCH_DEB=amd64 ;;
  *AArch64*) ARCH_DEB=arm64 ;;
  *80386* | *i386*) ARCH_DEB=i386 ;;
  *) printf 'Architecture ELF non prévue : %s\n' "$(readelf -h "$RUNNER" | grep Machine:)" >&2; exit 1 ;;
esac

# Date de publication du dépôt AppStream. SOURCE_DATE_EPOCH est lu par les
# outils de reproductibilité : sans lui, deux builds de la même version ne
# produisent pas le même octet et `apt` ne peut plus vérifier un miroir.
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  RELEASE_DATE="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%d)"
else
  RELEASE_DATE="$(date -u +%Y-%m-%d)"
fi

# Les listes de dépendances sont déclarées sur plusieurs lignes pour rester
# relisibles ; dpkg veut un seul champ séparé par des virgules.
join_comma() {
  local out='' w
  for w in $1; do out="$out${out:+, }$w"; done
  printf '%s' "$out"
}
DEPENDS="$(join_comma "$DEB_DEPENDS")"
RECOMMENDS="$(join_comma "$DEB_RECOMMENDS")"

if [ "$CHECK_DEPS" = 1 ]; then
  bash tool/check-linux-deps.sh "$BUNDLE"
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/uniflow-deb.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p \
  "$STAGE/DEBIAN" \
  "$STAGE/opt" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/metainfo"

# `cp -a` et non `cp -R` : les modes du runner et des greffons viennent du
# build, et `data/flutter_assets/.env` est un fichier caché qu'un `*` ferait
# disparaître silencieusement.
cp -a "$BUNDLE" "$STAGE/opt/uniflow_app"
chmod -R a+rX "$STAGE/opt/uniflow_app"

install -m 755 packaging/deb/usr/bin/uniflow "$STAGE/usr/bin/uniflow"
install -m 644 packaging/common/uniflow.desktop \
  "$STAGE/usr/share/applications/uniflow.desktop"

ICON_NAME="codes.kernelforge.uniflow.png"
found_icon=0
for path in packaging/common/icons/uniflow-*.png; do
  size="$(basename "$path" | sed -E 's/^uniflow-([0-9]+)\.png$/\1/')"
  dir="$STAGE/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  install -m 644 "$path" "$dir/$ICON_NAME"
  found_icon=1
done
[ "$found_icon" = 1 ] || {
  printf 'Aucune icône dans packaging/common/icons/ — le lanceur sera cassé.\n' >&2
  exit 1
}

render() {
  local in="$1" out="$2"
  shift 2
  local prog=() kv
  for kv in "$@"; do
    prog+=(-e "s|@${kv%%=*}@|${kv#*=}|g")
  done
  sed "${prog[@]}" "$in" > "$out"
}

render packaging/common/codes.kernelforge.uniflow.appdata.xml \
  "$STAGE/usr/share/metainfo/codes.kernelforge.uniflow.appdata.xml" \
  "VERSION_DEB=$VERSION_DEB" "RELEASE_DATE=$RELEASE_DATE"

install -m 755 packaging/deb/DEBIAN/postinst "$STAGE/DEBIAN/postinst"
install -m 755 packaging/deb/DEBIAN/postrm "$STAGE/DEBIAN/postrm"

# `Installed-Size` est en kibioctets et ne compte pas le répertoire DEBIAN, qui
# n'est jamais posé sur le système : on somme les deux arbres installés plutôt
# que de retirer DEBIAN d'un `du` global, dont le motif `--exclude` dépend de la
# façon dont du affiche les chemins.
INSTALLED_SIZE="$(du -s --block-size=1024 "$STAGE/opt" "$STAGE/usr" \
  | awk '{ total += $1 } END { print total + 0 }')"

render packaging/deb/DEBIAN/control.in "$STAGE/DEBIAN/control" \
  "VERSION_DEB=$VERSION_DEB" "ARCH_DEB=$ARCH_DEB" \
  "INSTALLED_SIZE=$INSTALLED_SIZE" "DEPENDS=$DEPENDS" "RECOMMENDS=$RECOMMENDS"
chmod 644 "$STAGE/DEBIAN/control"

# Les modes viennent de l'arborescence de build, donc portent le group-writable
# du umask 002 d'une session interactive (775 sur les dossiers, 664 sur les
# fichiers). Un paquet doit poser 755/644 : sinon `dpkg -i` laisse un /opt que le
# groupe de l'utilisateur constructeur peut modifier.
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -perm -u+x -exec chmod 755 {} +
find "$STAGE" -type f ! -perm -u+x -exec chmod 644 {} +

mkdir -p "$OUTPUT"
DEB="$OUTPUT/uniflow_${VERSION_DEB}_${ARCH_DEB}.deb"
# `--root-owner-group` plutôt que de rejouer un chown : le build tourne sous le
# uid de l'utilisateur, et un paquet dont les fichiers appartiennent à `ravel`
# se installe quand même mais leave un /opt appartenant à un particulier.
dpkg-deb --root-owner-group --build "$STAGE" "$DEB" >/dev/null

printf '\nPaquet écrit : %s (%s)\n' "$DEB" "$(du -h "$DEB" | cut -f1)"
dpkg-deb -I "$DEB" | sed -n '/Package:/,/Description:/p'
printf '\nContrôle : dpkg-deb -c %s   |   essais : sudo apt install ./%s\n' \
  "$(basename "$DEB")" "$(basename "$DEB")"
