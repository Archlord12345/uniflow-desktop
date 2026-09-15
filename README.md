# 🖥️ UniFlow Desktop — Tour de Contrôle Académique & IoT

![UniFlow Logo](assets/brand/uniflow_logo_horizontal.png)

UniFlow Desktop est la station de travail centralisée conçue pour l'administration universitaire, les chefs de départements et les équipes de sécurité du campus. Construite avec **Flutter**, elle offre une expérience bureau riche, optimisée pour la gestion de données complexes et le monitoring en temps réel.

## 🌟 Pourquoi une version Desktop ?
Alors que le mobile sert à la consommation, UniFlow Desktop sert à la **gestion**. Son interface "grand écran" permet de manipuler les structures académiques, de générer des rapports et de surveiller l'infrastructure IoT **Sentinelle** avec une précision maximale.

## 🛠️ Unification Appwrite & Améliorations
Le projet a été restructuré pour supprimer les données simulées (mocks) au profit d'une **intégration native avec l'infrastructure Appwrite** de KERNEL FORGE.
- **Accès Privilégié** : Les opérations sensibles passent par les Functions Appwrite (clé API côté serveur uniquement).
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
```

> ⚠️ **Ne jamais mettre de clé d'API serveur (`APPWRITE_API_KEY`) dans ce fichier.**
> `pubspec.yaml` déclare `.env` comme asset : tout ce qu'il contient est embarqué
> en clair dans le binaire et dans l'APK tablette. Les opérations privilégiées
> passent par les **Functions Appwrite**, qui détiennent la clé côté serveur.

## 🧰 Prérequis outillage

**Java 21 est requis.** Le projet tourne sous Gradle 9.1.0 / AGP 9.0.1. Si votre
`java` par défaut est plus récent (Java 25, par exemple), Gradle refuse de démarrer
avec `Gradle build failed due to Java/Gradle incompatibility`. Épinglez le JDK une
bonne fois pour toutes — c'est un réglage utilisateur, rien n'est écrit dans le dépôt :

```bash
flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64
```

**Sous Linux, `libwebkit2gtk-4.1-dev` est obligatoire.** Il vient de la chaîne
`appwrite` → `flutter_web_auth_2` → `desktop_webview_window`, dont le CMake réclame
WebKit. Sur Ubuntu 24.04, seul le paquet `4.1` existe :

```bash
sudo apt install -y libwebkit2gtk-4.1-dev
```

> Le message d'erreur CMake parle de `webkit2gtk-4.0` : c'est le *fallback* du
> plugin. S'il s'affiche, c'est que **4.1 manque aussi**. N'essayez pas d'installer
> le paquet `4.0`, il n'existe plus sur Ubuntu 24.04.

> Si le build Linux échoue ensuite sur
> `file INSTALL cannot copy ... to /usr/local/uniflow_app`, c'est un `CMakeCache.txt`
> périmé : lancez `flutter clean` puis relancez.

---
© 2026 **KERNEL FORGE** — L'excellence au service de la gestion académique.
