# Maquettes de référence du desktop

Le propriétaire a fourni le 2026-09-20 deux planches (`design_desktop/` à la
racine du dossier de travail, recopiées ici pour qu'elles suivent le dépôt).
**Toute refonte d'écran desktop se conforme à ces planches** : disposition,
densité, composants, couleurs.

| Planche | Écrans |
| --- | --- |
| `maquette-partie-2-enseignants-programmes-ue-salles.png` | 5 Gestion des enseignants · 6 Programmes / Facultés (arbre) · 7 Unités d'enseignement · 8 Gestion des salles |
| `maquette-partie-3-emploi-du-temps-presences-visio-stats.png` | 9 Constructeur d'emploi du temps · 10 Suivi des présences · 11 Gestion des conférences · 12 Tableau de bord statistiques |

## Palette (pied des planches)

| Rôle | Couleur | Constante `AppColors` |
| --- | --- | --- |
| Primaire (sidebar active, boutons, CM) | `#1E3A8A` | `primaryBlue` |
| Accent (TD, statuts positifs, courbes) | `#0D9488` | `teal` |
| Avertissement (TP, statuts « Occupée », alertes) | `#F59E0B` | `amber` |
| Fond de page | `#F3F4F6` | `background` |

## Ce que les planches imposent

- **Coquille** : sidebar claire à gauche (logo UniFlow, sections Pilotage /
  Scolarité / Pédagogie / Vie de campus / Système, entrée active sur fond
  `primary50` avec texte `primaryBlue`, compte en bas), en-tête de page avec
  titre à gauche et actions à droite (bouton primaire « + Ajouter … », boutons
  secondaires « Filtres », « Exporter »).
- **Listes** : tableaux denses sur carte blanche (`AppDataTable`), en-tête gris,
  pastilles de statut (`StatusBadge` : Permanent/Disponible en teal, Vacataire/
  Occupée en amber, Indisponible en rouge), colonne Actions (voir · modifier ·
  supprimer), pagination « 1 sur 30 » en pied. Barre de recherche + filtres
  déroulants au-dessus du tableau.
- **Arbre Programmes / Facultés** : volet gauche arborescent (faculté →
  département → licence → niveaux), volet droit « Détail du programme » avec
  fiche (nom, durée, semestres, crédits, responsable) et tableau des UE.
- **Constructeur d'emploi du temps** : filtres Filière / Niveau / Semestre,
  colonne « Cours à placer » (cartes colorées par type) à gauche, grille
  hebdomadaire Lun→Sam / 8h→18h à droite, créneau cible en pointillé, boutons
  Auto-générer · Valider · Exporter PDF · Imprimer · Annuler.
- **Présences** : quatre KPI (total inscrits, taux moyen avec anneau, présents
  moyen, absences non justifiées), tableau des séances, panneau « Détails de la
  session » + liste nominative, code QR, courbe d'évolution par semaine.
- **Conférences** : KPI (actives, planifiées, participants), tableau des
  conférences, dialogue « Créer une conférence » (En ligne / LAN, titre,
  description, UE, date, durée, mot de passe, « Créer et copier le lien »).
- **Statistiques** : filtres Période / Programme / Niveau, KPI avec variation
  (▲ vert / ▼ rouge), courbe d'évolution, histogramme par matière, anneau de
  réussite, « Top 5 UE par taux ».
- **Mouvement** : apparitions en fondu + translation courte (`MotionIn`), pas
  d'animation décorative sur les tableaux.
