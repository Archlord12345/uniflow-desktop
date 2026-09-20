import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/preferences_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

/// Point d'entrée de l'application Flutter.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: UniFlowApp()));
}

/// Widget racine de l'app UniFlow.
///
/// Au lancement, on résout d'abord la session Appwrite persistée sur la
/// machine ([sessionCheckProvider]) : tant qu'elle n'est pas résolue on affiche
/// un écran de chargement, ce qui évite de flasher la page de connexion pour un
/// utilisateur déjà authentifié.
class UniFlowApp extends ConsumerWidget {
  const UniFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionCheckProvider);
    final user = ref.watch(currentUserProvider);
    final darkMode = ref.watch(preferencesProvider.select((p) => p.darkMode));

    return MaterialApp(
      title: 'UniFlow',
      debugShowCheckedModeBanner:
          false, // masque le bandeau "DEBUG" rouge en haut à droite
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: session.when(
        loading: () => const _SplashScreen(),
        // Un échec de résolution (Appwrite injoignable) ne doit pas bloquer
        // l'app : on laisse l'utilisateur tenter de se connecter.
        error: (_, __) => const LoginScreen(),
        data: (_) => user == null ? const LoginScreen() : const MainShell(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
