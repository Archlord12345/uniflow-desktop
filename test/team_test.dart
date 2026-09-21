// Tests de la page Équipe KERNEL FORGE du desktop.
//
// La page portait quatre membres figés dans `management_screens.dart` quand le
// web en affichait neuf. Ces tests verrouillent ce qui la rend désormais
// identique aux deux autres clients : la lecture des documents de
// `team_members`, la traduction des couleurs sémantiques, le filtrage, et la
// silhouette neutre affichée à la place des initiales.

import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/team_member.dart';
import 'package:uniflow/screens/teams_screen.dart';
import 'package:uniflow/widgets/uni_icons.dart';
import 'package:uniflow/widgets/user_avatar.dart';

import 'layout_test_support.dart';

/// Document Appwrite minimal, tel que le renvoie `listDocuments`.
models.Document documentAvec(Map<String, dynamic> data, {String id = 'ravel'}) {
  return models.Document(
    $id: id,
    $sequence: '1',
    $collectionId: 'team_members',
    $databaseId: 'uniflow',
    $createdAt: '2026-09-01T00:00:00.000+00:00',
    $updatedAt: '2026-09-01T00:00:00.000+00:00',
    $permissions: const ['read("any")'],
    data: data,
  );
}

void main() {
  setUpAll(loadTestEnv);

  group('TeamMember.fromDocument', () {
    test('lit tous les champs du document', () {
      final membre = TeamMember.fromDocument(documentAvec({
        'slug': 'ravel',
        'name': 'NGHOMSI FEUKOUO RAVEL',
        'github': 'Archlord12345',
        'email': 'ravelnghomsi@gmail.com',
        'team': 'Leadership',
        'subTeam': 'Architecture & Direction',
        'role': 'Chef de projet & Architecte',
        'badge': 'Lead Architect',
        'accent': 'blue',
        'avatarFileId': 'photo-membre-0001',
        'displayOrder': 3,
      }));

      expect(membre.id, 'ravel');
      expect(membre.name, 'NGHOMSI FEUKOUO RAVEL');
      expect(membre.github, 'Archlord12345');
      expect(membre.team, 'Leadership');
      expect(membre.subTeam, 'Architecture & Direction');
      expect(membre.badge, 'Lead Architect');
      expect(membre.accent, 'blue');
      expect(membre.avatarFileId, 'photo-membre-0001');
      expect(membre.displayOrder, 3);
    });

    test('un document incomplet ne fait pas échouer l\'affichage', () {
      // Cas réel : un document écrit à la main depuis la console Appwrite, ou
      // créé avant l'ajout d'un attribut au schéma.
      final membre =
          TeamMember.fromDocument(documentAvec({'name': 'Membre Partiel'}));

      expect(membre.name, 'Membre Partiel');
      expect(membre.github, '');
      expect(membre.subTeam, '');
      expect(membre.avatarFileId, '');
      expect(membre.displayOrder, 0);
    });
  });

  group('mapTeamAccent', () {
    test('reconnaît les sept couleurs du schéma', () {
      expect(mapTeamAccent('blue'), TeamAccent.blue);
      expect(mapTeamAccent('purple'), TeamAccent.purple);
      expect(mapTeamAccent('emerald'), TeamAccent.emerald);
      expect(mapTeamAccent('amber'), TeamAccent.amber);
      expect(mapTeamAccent('rose'), TeamAccent.rose);
      expect(mapTeamAccent('cyan'), TeamAccent.cyan);
      expect(mapTeamAccent('indigo'), TeamAccent.indigo);
    });

    test('tolère la casse et les espaces', () {
      expect(mapTeamAccent('  EMERALD '), TeamAccent.emerald);
    });

    test('retombe sur le bleu pour une valeur inconnue', () {
      // Une carte bleue vaut mieux qu'un écran d'erreur si le schéma évolue.
      expect(mapTeamAccent('turquoise'), TeamAccent.blue);
      expect(mapTeamAccent(''), TeamAccent.blue);
      expect(mapTeamAccent(null), TeamAccent.blue);
    });

    test('chaque couleur a un fond, un texte et une bordure distincts', () {
      for (final accent in TeamAccent.values) {
        final style = teamAccentStyle(accent);
        expect(style.background, isNot(style.foreground));
        expect(style.border, isNot(style.background));
      }
    });
  });

  group('filterTeamMembers', () {
    test('« Tous » ne filtre rien', () {
      final equipe = equipeDeTest();
      expect(filterTeamMembers(equipe, 'Tous').length, equipe.length);
    });

    test('ne garde que l\'équipe demandée', () {
      final frontend = filterTeamMembers(equipeDeTest(), 'Frontend');
      expect(frontend, isNotEmpty);
      expect(frontend.every((m) => m.team == 'Frontend'), isTrue);
    });

    test('une catégorie sans membre rend une liste vide, sans erreur', () {
      expect(filterTeamMembers(equipeDeTest(), 'Marketing'), isEmpty);
    });

    test('les pastilles de filtre sont celles du web, dans le même ordre', () {
      expect(teamFilters, ['Tous', 'Leadership', 'Frontend', 'Backend']);
    });
  });

  group('teamMemberIcon', () {
    TeamMember membre(String role, String subTeam, String team) => TeamMember(
          id: 'x',
          slug: 'x',
          name: 'X',
          github: '',
          email: '',
          team: team,
          subTeam: subTeam,
          role: role,
          badge: '',
          accent: 'blue',
          avatarFileId: '',
          displayOrder: 0,
        );

    test('la base de données prime sur l\'équipe', () {
      expect(
          teamMemberIcon(
              membre('Backend Developer', 'SGBD & Infrastructure', 'Backend')),
          UniIcons.database());
    });

    test('le mobile se reconnaît à la sous-équipe', () {
      expect(
          teamMemberIcon(
              membre('Mobile Developer', 'Frontend Mobile App', 'Frontend')),
          UniIcons.deviceMobile(UniIcons.defaultStyle));
    });

    test('sinon l\'icône suit l\'équipe', () {
      expect(
          teamMemberIcon(membre('Chef de projet', 'Direction', 'Leadership')),
          UniIcons.badges());
      expect(
          teamMemberIcon(
              membre('Backend Developer', 'Microservices', 'Backend')),
          UniIcons.hardDrives(UniIcons.defaultStyle));
      expect(teamMemberIcon(membre('Frontend Developer', 'Web', 'Frontend')),
          UniIcons.code(UniIcons.defaultStyle));
    });
  });

  group('SilhouetteAvatar', () {
    testWidgets('sans photo, affiche une silhouette et aucun texte',
        (tester) async {
      await tester.pumpWidget(host(const SilhouetteAvatar(avatarFileId: '')));

      expect(find.byIcon(UniIcons.person(UniIconStyle.fill)), findsOneWidget);
      // Exigence du propriétaire : aucune écriture sur la photo de profil. Des
      // initiales donneraient l'impression d'une image ratée.
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('un identifiant vide ou nul donne le même résultat',
        (tester) async {
      await tester.pumpWidget(host(const SilhouetteAvatar()));
      expect(find.byIcon(UniIcons.person(UniIconStyle.fill)), findsOneWidget);
    });
  });

  group('écran Équipe', () {
    // La page est une longue liste : sur la surface de test par défaut
    // (800×600), les cartes du bas ne seraient pas construites, et les
    // assertions de comptage porteraient sur un écran tronqué. On donne donc au
    // test une fenêtre haute pour que toute l'équipe soit peinte.
    Future<void> afficher(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TeamsScreen()));
      await tester.pump();
    }

    testWidgets('affiche les membres lus dans la base', (tester) async {
      await afficher(tester);

      expect(find.text('NGHOMSI FEUKOUO RAVEL'), findsOneWidget);
      expect(find.text('Aliyatou Rachid Oumou Tourab'), findsOneWidget);
    });

    testWidgets('un membre sans photo reçoit une silhouette, pas des initiales',
        (tester) async {
      await afficher(tester);

      // Aucun des membres de test n'a de photo : chacun a sa silhouette, et
      // aucune carte n'affiche d'initiales.
      expect(find.byIcon(UniIcons.person(UniIconStyle.fill)),
          findsNWidgets(equipeDeTest().length));
    });

    testWidgets('les tuiles de statistiques comptent la liste affichée',
        (tester) async {
      await afficher(tester);

      expect(find.text('Membres au total'), findsOneWidget);
      expect(find.text('${equipeDeTest().length}'), findsOneWidget);
    });

    testWidgets('le filtre ne garde que l\'équipe choisie', (tester) async {
      await afficher(tester);

      await tester.tap(find.text('Leadership'));
      await tester.pumpAndSettle();

      expect(find.text('NGHOMSI FEUKOUO RAVEL'), findsOneWidget);
      expect(find.text('Aliyatou Rachid Oumou Tourab'), findsNothing);
    });

    testWidgets('un membre sans pseudo GitHub n\'a pas de bouton GitHub',
        (tester) async {
      await afficher(tester);

      // Deux membres de test sur trois ont un pseudo : le troisième, qui n'en a
      // pas, ne doit pas produire de bouton menant à `github.com/`.
      expect(find.textContaining('@'), findsNWidgets(2));
      expect(find.byIcon(UniIcons.mail(UniIconStyle.bold)), findsNWidgets(2));
    });
  });
}
