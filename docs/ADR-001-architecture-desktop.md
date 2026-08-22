# ADR-001 — Architecture UniFlow Desktop Flutter

**Statut :** accepté  
**Périmètre :** frontend Desktop Windows, Linux et macOS  
**Date :** 22 août 2026

## Décision

UniFlow utilise une architecture Flutter Desktop en couches légères. `main.dart` initialise l’application et le thème global. `LoginScreen` porte le parcours d’authentification. `MainShell` conserve une sidebar fixe et remplace uniquement la zone de contenu. Les écrans métier sont isolés dans `lib/screens`, les composants visuels partagés dans `lib/widgets`, les modèles dans `lib/models` et la palette dans `lib/theme`.

Cette décision conserve la structure déjà commencée au lieu de réécrire les écrans existants. La navigation est pilotée par `SidebarItem`, un enum typé qui évite les chaînes libres et permet d’ajouter une page sans dupliquer la sidebar.

## Contrat de chargement local

Au démarrage, l’application affiche `LoginScreen`. Après validation du formulaire, elle ouvre `MainShell`. Le shell présente le tableau de bord et les entrées de gestion. Les sources de vérité attendues pour la prochaine itération sont les adaptateurs Appwrite situés dans un service dédié du renderer Flutter ; les valeurs actuellement visibles sont explicitement des données de présentation et devront être remplacées par des repositories Appwrite avant la mise en production.

## Sécurité et différence avec la fiche Electron

La fiche mentionne `preload`, `contextIsolation` et IPC, qui sont des mécanismes Electron. Dans cette version Flutter Desktop, il n’existe pas de renderer Electron ni de preload Node : le code Dart s’exécute dans le runtime Flutter, sans Node integration. Aucun secret serveur ou clé privilégiée ne doit être embarqué dans l’application. Seuls l’endpoint et l’identifiant public Appwrite pourront être configurés côté client, avec les permissions Appwrite appropriées.

## Conséquences

L’approche permet une navigation cohérente, un code réutilisable et une migration progressive vers Appwrite. Elle impose de compléter ultérieurement la couche repository, la persistance du cache hors ligne, la synchronisation après reconnexion et les tests multi-OS.

## Arborescence

```text
lib/
├── main.dart
├── theme/                 # couleurs et ThemeData
├── models/                # student, teacher, UE, salle, planning
├── widgets/               # sidebar, top bar, cartes, badges, champs
└── screens/
    ├── login_screen.dart
    ├── main_shell.dart
    ├── dashboard_screen.dart
    ├── students_screen.dart
    ├── student_detail_screen.dart
    ├── teachers_screen.dart
    ├── teacher_detail_screen.dart
    ├── programs_screen.dart
    ├── teaching_units_screen.dart
    ├── classrooms_screen.dart
    ├── schedule_screen.dart
    └── management_screens.dart  # présences, conférences, communications, statistiques, paramètres
```

## État des trois premières tâches

La première tâche est couverte par cette ADR et l’arborescence. La deuxième est couverte par la navigation `MainShell`, la sidebar fixe et le parcours Login → Shell. La troisième est couverte par les tableaux de bord et écrans de gestion disponibles depuis chaque entrée du menu ; les variantes Étudiant et Enseignant restent une extension de rôle à brancher sur les mêmes composants.
