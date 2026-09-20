#!/usr/bin/env bash
# Écrit le `.env` embarqué dans le binaire à partir des secrets du dépôt.
#
# Le fichier est **réécrit** (et non complété) : le dépôt versionne déjà un
# `.env` public, et l'ancien workflow y ajoutait les lignes à la suite — la
# clé lue par `flutter_dotenv` était alors la première occurrence, celle du
# dépôt, pas celle du secret. Un secret absent arrête le build plutôt que de
# produire un binaire qui pointe sur un serveur mort.
set -euo pipefail

for name in APPWRITE_ENDPOINT APPWRITE_PROJECT_ID APPWRITE_DATABASE_ID APPWRITE_STORAGE_BUCKET_ID APPWRITE_API_FUNCTION_ID; do
  if [ -z "${!name:-}" ]; then
    echo "Secret manquant : $name" >&2
    exit 1
  fi
done

cat > .env <<EOF
# Généré par la CI à partir des secrets du dépôt (Appwrite Cloud).
APPWRITE_ENDPOINT=${APPWRITE_ENDPOINT}
APPWRITE_PROJECT_ID=${APPWRITE_PROJECT_ID}
APPWRITE_DATABASE_ID=${APPWRITE_DATABASE_ID}
# Offre gratuite : un seul bucket pour documents, photos de profil et pièces jointes.
APPWRITE_STORAGE_BUCKET_ID=${APPWRITE_STORAGE_BUCKET_ID}
APPWRITE_AVATAR_BUCKET_ID=${APPWRITE_STORAGE_BUCKET_ID}
APPWRITE_CHAT_FILES_BUCKET_ID=${APPWRITE_STORAGE_BUCKET_ID}
APPWRITE_API_FUNCTION_ID=${APPWRITE_API_FUNCTION_ID}
APP_WEB_URL=${APP_WEB_URL:-https://uniflow.kernelforge.codes}
EOF
echo ".env écrit ($(wc -l < .env) lignes)."
