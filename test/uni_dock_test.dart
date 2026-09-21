// Le bouton d'Uni ne recouvre aucune commande, sur aucun écran de la coquille.
//
// Constat du propriétaire (2026-09-21, sur le mobile ; même défaut ici) : posé
// au même endroit partout, le bouton flottant d'Uni cachait le bouton
// « Envoyer » de la messagerie, et son panneau ancré aussi. Chaque destination
// déclare désormais son bord inférieur (`BottomEdge`, `app_destination.dart`)
// et la coquille en déduit le coin d'Uni (`UniDock`).
//
// Ce test rend la déclaration obligatoire de fait : il monte **chaque
// destination** dans la coquille, pour **chaque profil** qui y a droit (le
// même écran change selon le rôle et le type de compte), à deux tailles de
// fenêtre, puis vérifie que le rectangle d'Uni ne croise aucune commande —
// d'abord les commandes fixes, puis celles des listes une fois chaque liste
// déroulée jusqu'au bout. Un écran qui gagne un bouton en bas à droite sans
// déclaration échoue ici avant d'atteindre un poste.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/app_destination.dart';
import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/models/user_role.dart';
import 'package:uniflow/repositories/messaging_repository.dart';
import 'package:uniflow/router/route_guard.dart';
import 'package:uniflow/screens/access_denied_screen.dart';
import 'package:uniflow/screens/main_shell.dart';
import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/ui/app_button.dart';
import 'package:uniflow/ui/app_shell.dart';
import 'package:uniflow/widgets/uni/uni_assistant.dart';
import 'package:uniflow/widgets/uni/uni_scenes.dart';

import 'layout_test_support.dart';

/// Deux fenêtres de bureau : la fenêtre par défaut, où le corps est le plus
/// étroit une fois la barre latérale dépliée, et un portable.
const List<Size> _sizes = [Size(1024, 700), Size(1366, 800)];

/// Les commandes qu'Uni ne doit pas recouvrir. Les tuiles de liste
/// (`InkWell`, `ListTile`) n'y sont pas : elles restent atteignables par le
/// reste de leur surface.
const List<Type> _controlTypes = [
  AppButton,
  IconButton,
  TextField,
  FilledButton,
  ElevatedButton,
  OutlinedButton,
  TextButton,
  FloatingActionButton,
  Switch,
  Checkbox,
];

/// Un compte connecté simulé : rôle et type de compte, ce qui décide de
/// l'écran affiché et de son contenu.
class _Profile {
  final String label;
  final UserRole role;
  final AccountType accountType;
  final bool superAdmin;

  const _Profile(this.label, this.role, this.accountType,
      {this.superAdmin = false});

  bool allows(AppDestination destination) =>
      canAccess(destination, role: role, accountType: accountType);

  UniFlowUser get user => UniFlowUser(
        id: 'u-${role.name}-${accountType.name}',
        email: '${role.name}@uniflow.edu',
        name: 'Test ${role.label}',
        accountType: accountType.wireValue,
        role: role.wireValue,
        username: 'test-${role.name}',
        isSuperAdmin: superAdmin,
      );
}

const List<_Profile> _profiles = [
  _Profile('étudiant', UserRole.student, AccountType.university),
  _Profile('délégué', UserRole.delegate, AccountType.university),
  _Profile('enseignant', UserRole.teacher, AccountType.university),
  _Profile('administrateur', UserRole.admin, AccountType.university),
  _Profile('étudiant indépendant', UserRole.student, AccountType.personal),
  _Profile('enseignant indépendant', UserRole.teacher, AccountType.personal),
  _Profile('admin plateforme', UserRole.admin, AccountType.platform,
      superAdmin: true),
];

void main() {
  setUpAll(loadTestEnv);

  group('bord inférieur des destinations', () {
    test('la messagerie déclare un composeur, le tableau de bord rien', () {
      expect(AppDestination.messaging.bottomEdge, BottomEdge.composer);
      expect(AppDestination.dashboard.bottomEdge, BottomEdge.free);
    });

    test('l\'ancrage suit le bord déclaré', () {
      expect(uniDockFor(BottomEdge.free), UniDock.right);
      expect(uniDockFor(BottomEdge.composer), UniDock.left);
      expect(UniDock.right.leftIn(800, UniLauncher.size),
          800 - UniDock.edgeInset - UniLauncher.size);
      expect(UniDock.left.leftIn(800, UniLauncher.size), UniDock.edgeInset);
      // Le panneau s'ouvre au-dessus du bouton, sans le toucher.
      expect(UniDock.panelBottomInset,
          greaterThan(UniDock.bottomInset + UniLauncher.size));
    });

    test('la marge basse des listes couvre Uni', () {
      expect(AppSpacing.uniClearance,
          greaterThanOrEqualTo(UniDock.bottomInset + UniLauncher.size + 8));
    });
  });

  for (final destination in AppDestination.values) {
    for (final profile in _profiles) {
      if (!profile.allows(destination)) continue;
      for (final size in _sizes) {
        testWidgets(
          'Uni ne recouvre aucune commande sur « ${destination.label} » '
          '(${profile.label}, ${size.width.toInt()}×${size.height.toInt()})',
          (tester) async {
            await _pumpShell(tester, destination,
                MainShell.buildDestination(destination), profile, size);
            await _expectUniClear(tester, destination);
          },
        );
      }
    }
  }

  for (final size in _sizes) {
    testWidgets(
      'écran « accès refusé » dans la coquille '
      '(${size.width.toInt()}×${size.height.toInt()})',
      (tester) async {
        const profile =
            _Profile('étudiant', UserRole.student, AccountType.university);
        const destination = AppDestination.accounts;
        expect(profile.allows(destination), isFalse);
        await _pumpShell(
          tester,
          destination,
          AccessDeniedScreen(
            destination: destination,
            role: profile.role,
            accountType: profile.accountType,
            onBackHome: () {},
          ),
          profile,
          size,
        );
        await _expectUniClear(tester, destination);
      },
    );

    testWidgets(
      'messagerie, conversation ouverte : le composeur reste libre, Uni et '
      'sa première apparition passent à gauche '
      '(${size.width.toInt()}×${size.height.toInt()})',
      (tester) async {
        UniPeek.shown.clear();
        await _pumpShell(
          tester,
          AppDestination.messaging,
          MainShell.buildDestination(AppDestination.messaging),
          _profiles.first,
          size,
          overrides: [
            conversationsProvider
                .overrideWith((ref) async => [_conversation()]),
          ],
        );
        // Le composeur n'existe que quand une conversation est sélectionnée.
        await tester.tap(find.text('Prof. Test'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.widgetWithText(AppButton, 'Envoyer'), findsOneWidget);
        await _expectUniClear(tester, AppDestination.messaging);

        // Première apparition : Uni passe la tête par le bord gauche, au-dessus
        // de son bouton, et ne touche pas le composeur non plus.
        await tester.pump(const Duration(milliseconds: 1900));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.widget<UniPeek>(find.byType(UniPeek)).edge,
            UniPeekEdge.left);
        final peekBody = find
            .descendant(
                of: find.byType(UniPeek),
                matching: find.byType(GestureDetector))
            .first;
        final peekRect = tester.getRect(peekBody);
        final bodyRect = tester.getRect(find.byType(UniAssistantDock));
        expect(peekRect.left, closeTo(bodyRect.left, 0.5),
            reason:
                'la première apparition doit suivre Uni dans le coin gauche');
        expect(
            _controlsUnder(tester, peekRect, includeScrolling: true), isEmpty,
            reason: 'la première apparition d\'Uni recouvre une commande');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
      'le glissement d\'un coin à l\'autre est animé, sauf mouvement '
      'réduit', (tester) async {
    tester.view.physicalSize = _sizes.first;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final selected = ValueNotifier(AppDestination.dashboard);
    addTearDown(selected.dispose);
    Widget shell(AppDestination destination) => AppShell(
          selected: destination,
          onSelect: (_) {},
          body: MainShell.buildDestination(destination),
        );

    await tester.pumpWidget(host(
      ValueListenableBuilder(
          valueListenable: selected,
          builder: (context, destination, _) => shell(destination)),
      user: _profiles.first.user,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final body = tester.getRect(find.byType(UniAssistantDock));
    final atRight = tester.getRect(find.byType(UniLauncher));
    expect(atRight.right, closeTo(body.right - UniDock.edgeInset, 0.5));

    selected.value = AppDestination.messaging;
    await tester.pump();
    await tester.pump(UniAssistantDock.slideDuration ~/ 2);
    final midway = tester.getRect(find.byType(UniLauncher));
    expect(midway.left, greaterThan(body.left + UniDock.edgeInset + 1));
    expect(midway.left, lessThan(atRight.left - 1));

    await tester.pump(UniAssistantDock.slideDuration);
    final atLeft = tester.getRect(find.byType(UniLauncher));
    expect(atLeft.left, closeTo(body.left + UniDock.edgeInset, 0.5));
    expect(tester.takeException(), isNull);

    // Mouvement réduit : le changement de coin est immédiat.
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: host(
        ValueListenableBuilder(
            valueListenable: selected,
            builder: (context, destination, _) => shell(destination)),
        user: _profiles.first.user,
      ),
    ));
    await tester.pump();
    selected.value = AppDestination.dashboard;
    await tester.pump();
    await tester.pump();
    final backRight = tester.getRect(find.byType(UniLauncher));
    expect(backRight.right, closeTo(body.right - UniDock.edgeInset, 0.5));
  });
}

/// Une conversation avec quelques messages, pour ouvrir le fil et faire
/// apparaître le composeur.
Conversation _conversation() => Conversation(
      id: 'c1',
      name: 'Prof. Test',
      role: 'TEACHER',
      email: 'prof@uniflow.edu',
      username: 'prof',
      avatarFileId: '',
      online: false,
      lastMessage: 'À demain.',
      time: '2026-09-21T10:02:00Z',
      unread: 0,
      messages: [
        for (var i = 0; i < 12; i++)
          ChatMessage(
            id: 'm$i',
            mine: i.isOdd,
            text: i.isOdd ? 'Merci, à demain.' : 'Le cours est déplacé en B12.',
            time: '2026-09-21T10:${i.toString().padLeft(2, '0')}:00Z',
            senderId: i.isOdd ? 'me' : 'prof',
          ),
      ],
    );

/// La coquille entière autour de l'écran de [destination], comme en
/// production : c'est elle qui place Uni, il faut donc la monter plutôt que
/// l'écran seul. Les animations sont coupées : le glissement d'un coin à
/// l'autre est testé à part.
Future<void> _pumpShell(
  WidgetTester tester,
  AppDestination destination,
  Widget body,
  _Profile profile,
  Size size, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: host(
        AppShell(selected: destination, onSelect: (_) {}, body: body),
        user: profile.user,
        overrides: overrides,
      ),
    ),
  );
  // Deux passes : la première construit, la seconde laisse les providers
  // neutralisés livrer leurs valeurs et peint.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
}

/// Uni est dans le coin déclaré par [destination] et ne croise aucune
/// commande, fixe ou de liste déroulée.
Future<void> _expectUniClear(
    WidgetTester tester, AppDestination destination) async {
  final launcher = find.byType(UniLauncher);
  expect(launcher, findsOneWidget);
  final uniRect = tester.getRect(launcher);
  final bodyRect = tester.getRect(find.byType(UniAssistantDock));
  final dock = uniDockFor(destination.bottomEdge);
  expect(
      uniRect.left,
      closeTo(
          bodyRect.left + dock.leftIn(bodyRect.width, UniLauncher.size), 0.5),
      reason: 'Uni doit être dans le coin ${dock.name}');
  expect(uniRect.bottom, closeTo(bodyRect.bottom - UniDock.bottomInset, 0.5));

  // 1. Commandes fixes : celles qui ne défilent pas.
  expect(_controlsUnder(tester, uniRect, includeScrolling: false), isEmpty,
      reason: 'une commande fixe est sous Uni ; déclarer le bord inférieur de '
          '« ${destination.label} » dans app_destination.dart');

  // 2. Commandes des listes, une fois chaque liste déroulée au bout : c'est là
  // que la dernière ligne se retrouve sous le bouton si la liste n'a pas de
  // marge basse. Deux passes : une liste construite à la demande n'a une
  // étendue exacte qu'une fois sa fin construite.
  for (var pass = 0; pass < 2; pass++) {
    for (final scrollable
        in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
      final position = scrollable.position;
      if (position.axis != Axis.vertical || !position.hasContentDimensions) {
        continue;
      }
      position.jumpTo(position.maxScrollExtent);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(_controlsUnder(tester, uniRect, includeScrolling: true), isEmpty,
      reason: 'une commande de liste finit sous Uni ; donner à la liste une '
          'marge basse (AppSpacing.uniClearance)');
  expect(tester.takeException(), isNull);
}

/// Les commandes dont le rectangle croise [rect], décrites pour le message
/// d'échec. Sans [includeScrolling], celles qui vivent dans un `Scrollable`
/// sont ignorées : elles ne sont pas encore à leur place définitive.
List<String> _controlsUnder(WidgetTester tester, Rect rect,
    {required bool includeScrolling}) {
  final found = <String>[];
  for (final type in _controlTypes) {
    for (final element in find.byType(type).evaluate()) {
      // Uni contient ses propres commandes (panneau, bulle) ; elles ne
      // comptent pas.
      if (_isInside(element, UniLauncher) ||
          _isInside(element, UniAssistantPanel) ||
          _isInside(element, UniPeek)) {
        continue;
      }
      if (!includeScrolling && _isInside(element, Scrollable)) continue;
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final controlRect = box.localToGlobal(Offset.zero) & box.size;
      if (controlRect.overlaps(rect)) {
        found.add('$type à $controlRect (Uni : $rect)');
      }
    }
  }
  return found;
}

bool _isInside(Element element, Type ancestorType) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget.runtimeType == ancestorType) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}
