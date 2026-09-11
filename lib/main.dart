import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

/// Point d'entrée de l'application Flutter.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: UniFlowApp()));
}

/// Widget racine de l'app UniFlow.
/// Configure le thème global et définit l'écran de démarrage.
/// À terme, on remplacera `home: LoginScreen()` par une gestion de routes
/// (ex: go_router) pour naviguer entre login, dashboard, gestion étudiants, etc.
class UniFlowApp extends StatelessWidget {
  const UniFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniFlow',
      debugShowCheckedModeBanner: false, // masque le bandeau "DEBUG" rouge en haut à droite
      theme: AppTheme.lightTheme, // thème centralisé défini dans theme/app_theme.dart
      home: const LoginScreen(), // premier écran affiché au lancement
    );
  }
}
