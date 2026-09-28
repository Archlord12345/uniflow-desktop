#!/usr/bin/env bash
# Contrôle des bibliothèques système que le bundle Linux charge réellement.
#
# Le risque visé : un greffon ajoute une dépendance système, le .deb et le .rpm
# continuent de se construire sans la déclarer, l'application démarre sur la
# machine de build et ne démarre plus chez l'étudiant. Ce script compare la
# liste des sonames externes du bundle à une base de référence versionnée, et
# échoue dès qu'un soname apparait sans avoir été relu.
#
# Pourquoi une base de référence et pas `dpkg -S` sur chaque soname : la mapping
# complete prend plus de deux minutes (une requête par soname sur la base dpkg),
# ce qui est inutilable dans un job de build. La mapping n'est faite que sur les
# nouveanx, c'est-à-dire rien dans le cas normal.
#
# Usage :
#   tool/check-linux-deps.sh [chemin/du/bundle]   # contrôle
#   tool/check-linux-deps.sh --update [bundle]    # accepte l'état actuel
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
BASELINE="packaging/common/linux-sonames.txt"
UPDATE=0
if [ "${1:-}" = "--update" ]; then
  UPDATE=1
  shift
fi
BUNDLE="${1:-build/linux/x64/release/bundle}"

if [ ! -d "$BUNDLE" ]; then
  echo "Bundle introuvable : $BUNDLE (lance \`flutter build linux --release\`)" >&2
  exit 1
fi

# shellcheck source=packaging/common/dependencies.env
. packaging/common/dependencies.env

CURRENT="$(mktemp)"
ALL="$(mktemp)"
LDD_OUT="$(mktemp)"
trap 'rm -f "$CURRENT" "$ALL" "$LDD_OUT"' EXIT

# Tous les sonames cités par le runner et par chaque .so livré, avec leur chemin
# résolu. Le bundle se charge lui-même de ses bibliothèques privées (RUNPATH
# $ORIGIN/lib) : celles-la ne regardent pas le gestionnaire de paquets.
BINARY="$BUNDLE/${APP_BINARY_NAME:-uniflow_app}"
[ -f "$BINARY" ] || BINARY="$(find "$BUNDLE" -maxdepth 1 -type f -executable | head -1)"
# `|| true` : `ldd` sort en code 1 dès qu'une bibliothèque manque, ce qu'on veut
# signaler soi-même juste en dessous plutôt que de quitter sans un mot.
{
  ldd "$BINARY"
  find "$BUNDLE/lib" -maxdepth 1 -type f \( -name '*.so' -o -name '*.so.*' \) -exec ldd {} +
} 2>/dev/null > "$LDD_OUT" || true

# Le format d'une ligne utile est « libX.so.0 => /usr/lib/…/libX.so.0 (0x00007f…) » :
# l'adresse en fin de ligne interdit d'ancrer la correspondance sur `$`.
sed -nE 's/^[[:space:]]*([^ ]+)[[:space:]]+=>[[:space:]]+(\/[^ ]+).*/\1 \2/p' "$LDD_OUT" | sort -u > "$ALL"

NOT_FOUND="$(grep -oE '^[[:space:]]*[^ ]+ => not found' "$LDD_OUT" | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
if [ -n "$NOT_FOUND" ]; then
  echo "ÉCHEC : le chargeur ne résout pas ces bibliothèques sur la machine de build :" >&2
  echo "        $NOT_FOUND" >&2
  echo "        Le paquet livré ne démarrera pas ailleurs non plus." >&2
  exit 1
fi

# `index()` plutôt qu'une correspondance d'expression régulière : le chemin du
# bundle peut contenir des espaces et n'importe quel métacaractère.
awk -v bundle="$(realpath "$BUNDLE")" 'index($2, bundle "/") != 1 {print $1}' "$ALL" | sort -u > "$CURRENT"

echo "Bibliothèques externes chargées par le bundle : $(wc -l < "$CURRENT")"

# Les sonames critiques doivent être résolus, dans le bundle ou sur le système :
# sans eux la fenêtre ne s'ouvre pas du tout.
LDCACHE="$(ldconfig -p 2>/dev/null || true)"
MISSING=""
for s in $CRITICAL_SONAMES; do
  if ! grep -q "^$s\$" "$CURRENT" && ! printf '%s' "$LDCACHE" | grep -q "$s ("; then
    MISSING="$MISSING $s"
  fi
done

if [ "$UPDATE" = 1 ]; then
  if [ ! -f "$BASELINE" ] || ! cmp -s "$CURRENT" "$BASELINE"; then
    cp "$CURRENT" "$BASELINE"
    echo "Base de référence réécrite : $BASELINE"
  else
    echo "Base de référence déjà à jour."
  fi
  exit 0
fi

if [ ! -f "$BASELINE" ]; then
  echo "Base de référence absente : $BASELINE — génère-la avec \`--update\` puis relis-la." >&2
  exit 1
fi

ADDED="$(comm -13 "$BASELINE" "$CURRENT")"
REMOVED="$(comm -23 "$BASELINE" "$CURRENT")"

if [ -n "$REMOVED" ]; then
  echo "Bibliothèques disparues de la liste (inoffensif, à acter avec --update) :"
  printf '  %s\n' $REMOVED
fi

STATUS=0
if [ -n "$ADDED" ]; then
  STATUS=1
  echo "ÉCHEC : de nouvelles bibliothèques système sont chargées sans être déclarées." >&2
  echo "Pour chacune, le paquet Debian/Ubuntu fournisseur et ce qu'il faut faire :" >&2
  for s in $ADDED; do
    path="$(awk -v s="$s" '$1 == s {print $2; exit}' "$ALL")"
    # dpkg -S ne connaît que les chemins réels : /lib/x86_64-linux-gnu est un
    # lien de la fusion /usr, il faut le réécrire pour obtenir le fournisseur.
    pkg="$(dpkg -S "$path" 2>/dev/null | head -1 | cut -d: -f1 || true)"
    [ -n "$pkg" ] || pkg="$(dpkg -S "/usr$path" 2>/dev/null | head -1 | cut -d: -f1 || true)"
    echo "  + $s  <- $path  paquet: ${pkg:-inconnu}" >&2
  done
  echo "Relis packaging/common/dependencies.env, ajoute le paquet si nécessaire," >&2
  echo "puis valide l'état : tool/check-linux-deps.sh --update" >&2
fi

if [ -n "$MISSING" ]; then
  STATUS=1
  echo "ÉCHEC : sonames critiques introuvables sur la machine de build :$MISSING" >&2
fi

if [ "$STATUS" = 0 ]; then
  echo "Contrôle des dépendances : OK ($(wc -l < "$CURRENT") sonames, base à jour)"
fi
exit "$STATUS"
