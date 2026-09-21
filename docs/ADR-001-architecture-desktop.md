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

## Feuille de présence des visioconférences (ajout du 21 septembre 2026)

Le poste qui héberge une réunion est le seul à savoir qui y était : aucun serveur central n’intervient, et il doit pouvoir rendre compte d’une séance tenue sans Internet. La feuille de présence est donc **produite et conservée sur le poste hôte**, dans `lib/services/conference/` :

- `ConferenceAttendance` / `AttendanceEntry` (`conference_attendance.dart`) décrivent une réunion et ses participants : identité LiveKit, nom affiché, `userId` Appwrite déclaré par le client au moment du ticket, connexions successives (`joinedAt` / `leftAt`), durée cumulée. Un participant est **présent** si sa durée cumulée atteint un seuil réglable, 50 % de la durée de la réunion par défaut ; **partiel** en dessous ; **absent** s’il a reçu un ticket sans jamais se connecter.
- Deux sources indépendantes alimentent la feuille, appliquées dans l’ordre reçu par `LiveAttendanceController` (`providers/attendance_provider.dart`) : les tickets délivrés par l’API de jonction (`ConferenceHostServer`), et les webhooks `participant_joined` / `participant_left` que le serveur média embarqué poste sur la boucle locale, signés HS256 avec la clé de la salle et vérifiés (`livekit_webhook.dart`) avant d’être pris en compte. L’hôte n’est jamais compté parmi les participants.
- La feuille est écrite après chaque événement dans `~/.uniflow/conference/presences/<id>.json` (`FileAttendanceStore`, écriture atomique), une par réunion. Une feuille laissée ouverte par un arrêt brutal est close à sa dernière activité lors de la relecture, pour que ses connexions « encore ouvertes » ne cumulent pas des jours de présence.
- Les exports PDF et Excel (`attendance_export.dart`, fonction pure testée indépendamment du rendu) sont enregistrés dans `Documents/UniFlow/Présences/presence-<slug>-<AAAA-MM-JJ>.pdf|.xlsx` puis proposés à l’ouverture (`attendance_export_service.dart`).

La remontée de ces présences vers `course_attendances` d’Appwrite n’est pas faite : elle suppose de rattacher la réunion à une séance d’emploi du temps et une file d’attente hors ligne ; `scheduleId` est prévu sur la feuille pour cela.

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
