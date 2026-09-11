# 🖥️ UniFlow Desktop — Tour de Contrôle Académique & IoT

![UniFlow Logo](assets/images/logo.png)

UniFlow Desktop est la station de travail centralisée conçue pour l'administration universitaire, les chefs de départements et les équipes de sécurité du campus. Construite avec **Flutter**, elle offre une expérience bureau riche, optimisée pour la gestion de données complexes et le monitoring en temps réel.

## 🌟 Pourquoi une version Desktop ?
Alors que le mobile sert à la consommation, UniFlow Desktop sert à la **gestion**. Son interface "grand écran" permet de manipuler les structures académiques, de générer des rapports et de surveiller l'infrastructure IoT **Sentinelle** avec une précision maximale.

## 🛠️ Unification Appwrite & Améliorations
Le projet a été restructuré pour supprimer les données simulées (mocks) au profit d'une **intégration native avec l'infrastructure Appwrite** de KERNEL FORGE.
- **Accès Privilégié** : Gestion des clés d'API UniFlow directement dans les paramètres.
- **Performance Native** : Compilation optimisée pour Windows et Linux.
- **Mode Tablette** : Une version spécifique APK est générée pour les tablettes grand format, utilisant l'interface Desktop pour une mobilité administrative sur le terrain.

## 🔥 Fonctionnalités Maîtresses

### 1. Administration & Structure
- **Gestion des Ressources** : Interface CRUD complète pour les Étudiants, Enseignants, Salles et Programmes.
- **Structure Académique** : Configuration des facultés, départements et niveaux (L1-D3).
- **Gestion des Notes & Devoirs** : Outils de saisie de masse et publication officielle des résultats.

### 2. Sentinelle IoT — Surveillance Edge AI
- **Monitoring Santé** : Vue d'ensemble des kiosques de santé connectés.
- **Vigie IA** : Console de surveillance des flux vidéo locaux (Edge AI). Détection automatique de chutes ou comportements suspects sans stockage cloud (Privacy by design).
- **Journal d'Événements** : Traçabilité complète des incidents de sécurité et de santé sur le campus.

### 3. Communication & Statistiques
- **Centre de Messagerie** : Gestion des annonces globales et des communications officielles.
- **Statistiques Avancées** : Tableaux de bord analytiques sur l'assiduité, les taux de réussite et les flux de présence.
- **Bibliothèque Numérique** : Gestion des buckets de stockage Appwrite pour les ressources pédagogiques.

## 🚀 CI/CD & Déploiement Multi-Cibles
Le projet utilise trois workflows GitHub Actions distincts pour la production :
1. **Windows** : Génération de l'exécutable `.exe`.
2. **Linux** : Création de paquets `.deb` et `.rpm`.
3. **Android Tablet** : Génération d'une APK optimisée pour les écrans larges (Tablettes).

## ⚙️ Configuration
Fichier `.env` requis :
```env
APPWRITE_ENDPOINT=https://appwrite.kernelforge.codes/v1
APPWRITE_PROJECT_ID=6a959096002a64d9d4e6
APPWRITE_DATABASE_ID=uniflow
APPWRITE_STORAGE_BUCKET_ID=uniflow_assets
UNIFLOW_API_TOKEN=votre_token_secret
```

---
© 2026 **KERNEL FORGE** — L'excellence au service de la gestion académique.
