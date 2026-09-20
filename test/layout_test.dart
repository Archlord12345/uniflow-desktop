// Test de mise en page du desktop.
//
// Le desktop n'est pas seulement redimensionnable : c'est la plateforme où
// l'utilisateur redimensionne réellement la fenêtre, souvent jusqu'à une
// largeur de téléphone. Chaque écran est donc peint à cinq largeurs, dont une
// très étroite, et le test échoue dès qu'un `Row` ou une `Column` ne rentre
// pas dans la place disponible.
//
// C'est ce test qui attrape les « A RenderFlex overflowed by N pixels » que
// l'utilisateur voyait en console, et qui faisaient perdre la connexion au
// périphérique dans `flutter run`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/screens/academic_management_screens.dart';
import 'package:uniflow/screens/classrooms_screen.dart';
import 'package:uniflow/screens/dashboard_screen.dart';
import 'package:uniflow/models/user_role.dart';
import 'package:uniflow/screens/accounts_screen.dart';
import 'package:uniflow/screens/attendance_screen.dart';
import 'package:uniflow/screens/login_screen.dart';
import 'package:uniflow/screens/notifications_screen.dart';
import 'package:uniflow/screens/personal_workspace_screen.dart';
import 'package:uniflow/screens/register_screen.dart';
import 'package:uniflow/screens/main_shell.dart';
import 'package:uniflow/screens/management_screens.dart';
import 'package:uniflow/screens/teams_screen.dart';
import 'package:uniflow/screens/messaging_screen.dart';
import 'package:uniflow/screens/programs_screen.dart';
import 'package:uniflow/screens/schedule_screen.dart';
import 'package:uniflow/screens/students_screen.dart';
import 'package:uniflow/screens/teachers_screen.dart';
import 'package:uniflow/screens/teaching_units_screen.dart';

import 'layout_test_support.dart';

/// Tailles de fenêtre balayées : de la fenêtre quasi fermée à l'écran large.
const List<Size> _sizes = [
  Size(420, 620), // fenêtre réduite au minimum
  Size(760, 640), // juste sous le point de bascule du login
  Size(1024, 720), // fenêtre par défaut
  Size(1280, 800), // portable 13 pouces
  Size(1440, 900), // écran large
];

/// Le texte agrandi : un utilisateur qui règle la taille de police du système
/// ne doit pas faire déborder les écrans.
const List<double> _textScales = [1.0, 1.3];

void main() {
  setUpAll(loadTestEnv);

  /// Les écrans testés, avec leur nom pour le message d'échec.
  final screens = <String, Widget>{
    'Connexion': const LoginScreen(),
    'Inscription': const RegisterScreen(),
    'Inscription indépendante': const RegisterScreen(initialType: AccountType.personal),
    'Espace personnel': const PersonalWorkspaceScreen(),
    'Coquille': const MainShell(),
    'Tableau de bord': const DashboardScreen(),
    'Étudiants': const StudentsScreen(),
    'Enseignants': const TeachersScreen(),
    'UE': const TeachingUnitsScreen(),
    'Programmes': const ProgramsScreen(),
    'Salles': const ClassroomsScreen(),
    'Emploi du temps': const ScheduleScreen(),
    'Présences': const AttendanceScreen(),
    'Devoirs': const AssignmentsManagementScreen(),
    'Notes': const GradesManagementScreen(),
    'Bibliothèque': const LibraryManagementScreen(),
    'Conférences': const ConferencesScreen(),
    'Sentinelle': const SentinelleManagementScreen(),
    'Équipe': const TeamsScreen(),
    'Messagerie': const MessagingScreen(),
    'Paiements': const PaymentsManagementScreen(),
    'Statistiques': const StatisticsScreen(),
    'Réglages': const SettingsScreen(),
    'Comptes': const AccountsScreen(),
    'Notifications': const NotificationsScreen(),
  };

  for (final entry in screens.entries) {
    for (final size in _sizes) {
      for (final scale in _textScales) {
        testWidgets(
          '${entry.key} ne déborde pas en ${size.width.toInt()}×${size.height.toInt()} '
          '(texte ×$scale)',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
                child: host(entry.value),
              ),
            );
            // Deux passes : la première construit l'arbre, la seconde peint —
            // c'est à la peinture que Flutter signale un débordement.
            //
            // L'échec affiche la chaîne `debugCreator` (« Row ← Padding ←
            // DecoratedBox ← Container ← TeachersScreen ») : c'est elle qui
            // désigne le widget fautif, et elle voyage dans l'exception
            // elle-même. Inutile d'aller chercher les `informationCollector`
            // du `FlutterErrorDetails`.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
