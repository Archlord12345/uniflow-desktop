import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/main.dart';

void main() {
  testWidgets('UniFlow affiche l’écran de connexion', (tester) async {
    await tester.pumpWidget(const UniFlowApp());
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Sélectionner votre rôle'), findsOneWidget);
  });

  testWidgets('UniFlow ouvre le shell après connexion', (tester) async {
    await tester.pumpWidget(const UniFlowApp());
    await tester.tap(find.text('Se connecter'));
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Étudiants'), findsWidgets);
  });
}
