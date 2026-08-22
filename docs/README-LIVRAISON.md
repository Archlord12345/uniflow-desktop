# Livraison UniFlow Desktop Flutter

## Travail réalisé

Le frontend existant a été conservé. Les écrans déjà présents — connexion, dashboard administrateur, étudiants, détail étudiant, enseignants, programmes, unités d’enseignement, salles et emploi du temps — n’ont pas été réécrits. La navigation du `MainShell` a été étendue pour que les entrées **Présences**, **Conférences**, **Communications**, **Statistiques** et **Paramètres** ouvrent désormais de vrais écrans au lieu de l’espace réservé « Page à venir ».

Les nouveaux écrans reprennent la palette du référentiel : bleu UniFlow, teal, fond gris clair, cartes blanches, bordures discrètes, boutons d’action en haut et tableaux larges adaptés au Desktop. L’écran Présences propose des indicateurs, filtres et historique des sessions. L’écran Conférences propose les indicateurs et la liste des conférences. Communications propose la liste des annonces et un panneau de rédaction. Statistiques propose les indicateurs, graphiques de synthèse et le classement des UE. Paramètres propose les préférences générales et le compte administrateur.

Le test Flutter de démonstration obsolète a été remplacé par deux tests ciblant l’écran de connexion et le passage vers le shell après connexion. Le fichier `docs/ADR-001-architecture-desktop.md` formalise l’architecture, l’arborescence et l’adaptation des trois premières tâches du PDF au contexte Flutter.

## Correspondance avec les trois premières tâches

| Tâche du PDF | Réalisation dans le projet | Preuve |
|---|---|---|
| Choisir l’architecture UI et le contrat de chargement local | Architecture Flutter en couches légères, shell partagé, palette et contrats documentés | `docs/ADR-001-architecture-desktop.md` |
| Navigation et parcours d’authentification | `LoginScreen` → `MainShell`, sidebar fixe et navigation typée par `SidebarItem` | `lib/screens/main_shell.dart`, `test/widget_test.dart` |
| Dashboards Étudiant, Enseignant et Administration | Dashboard administrateur existant préservé et modules de gestion ajoutés ; les variantes de rôle pourront réutiliser le même shell et les mêmes composants | `lib/screens/dashboard_screen.dart`, `lib/screens/management_screens.dart` |

## Limites et prochaine intégration

Le PDF décrit un dépôt Electron alors que le livrable fourni est un projet Flutter Dart. Les concepts `preload`, `contextIsolation` et IPC ne sont donc pas transposables littéralement. L’ADR explique cette différence et interdit l’intégration de secrets serveur dans le client.

Les données des écrans ajoutés sont des données de présentation en attendant la connexion Appwrite. Elles doivent être remplacées par des repositories Appwrite autorisés, puis complétées par un cache local, une synchronisation après reconnexion, les permissions par rôle et les notifications natives. Aucun secret privilégié n’a été ajouté.

L’environnement de travail ne contient pas les commandes `flutter` ou `dart`, donc l’exécution de `flutter test`, l’analyse statique et le packaging multi-OS n’ont pas pu être exécutés ici. Le projet final conserve toutefois la configuration Flutter et les fichiers natifs fournis dans l’archive d’origine ; il devra être vérifié avec le SDK Flutter installé sur la machine de développement avant livraison candidate.
