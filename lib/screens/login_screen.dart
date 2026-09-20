import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/motion.dart';
import 'forgot_password_dialog.dart';
import 'main_shell.dart';
import 'register_screen.dart';

/// Écran de connexion.
///
/// Le choix Compte universitaire / Compte indépendant est demandé en premier :
/// il ne change pas l'authentification (Appwrite ne connaît qu'un compte),
/// mais il est **vérifié** après connexion. Un compte universitaire qui se
/// connecte en « indépendant » est prévenu et redirigé vers son vrai espace :
/// c'est ce qui évite qu'un étudiant cherche ses cours dans un espace
/// personnel vide.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AccountType _accountType = AccountType.university;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Saisissez votre email et votre mot de passe.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _notice = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.login(_emailController.text, _passwordController.text);
      final user = await authRepo.getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Session ouverte, mais le compte n\'a pas pu être relu. '
              'Vérifiez la connexion réseau et réessayez.';
        });
        return;
      }

      // Le type choisi à l'écran n'est qu'une intention ; le type réel est
      // celui du compte. On le dit plutôt que d'ouvrir le mauvais espace.
      // Un compte `PLATFORM` entre par « Compte universitaire » : c'est
      // l'espace d'établissement, étendu à toutes les universités.
      final expected = _accountType == AccountType.university
          ? user.accountKind.seesInstitution
          : user.isPersonal;
      if (!expected) {
        _notice = user.isPersonal
            ? 'Ce compte est un compte indépendant : ouverture de votre espace personnel.'
            : 'Ce compte est rattaché à un établissement : ouverture de votre espace universitaire.';
      } else if (user.isPlatform) {
        _notice = 'Administration de la plateforme : tous les établissements sont visibles.';
      }

      ref.read(currentUserProvider.notifier).state = user;
      ref.read(currentDestinationProvider.notifier).state = null;
      setState(() => _isLoading = false);
      if (_notice != null) {
        showFeedback(context, message: _notice!, success: true, duration: const Duration(seconds: 5));
      } else {
        showFeedback(context, message: 'Bienvenue, ${user.name}.', detail: user.userRole.scope);
      }
      Navigator.of(context).pushReplacement(softRoute(const MainShell()));
    } on AppwriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = readableAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connexion impossible : $e';
      });
    }
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.of(context).push<bool>(
      softRoute(RegisterScreen(initialType: _accountType)),
    );
    if (registered == true && mounted) {
      Navigator.of(context).pushReplacement(softRoute(const MainShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(form: _form());
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Se connecter',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: 6),
        const Text(
          'Connectez-vous à votre compte UniFlow',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 22),
        AccountTypeSelector(
          value: _accountType,
          onChanged: (type) => setState(() => _accountType = type),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 20),
        AppTextField(
          label: 'Email',
          hint: 'prenom.nom@universite.cm',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Mot de passe',
          hint: '••••••••',
          controller: _passwordController,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 2,
          children: [
            InkWell(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        activeColor: AppColors.primaryBlue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Rester connecté',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => showForgotPasswordDialog(
                context,
                initialEmail: _emailController.text,
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Mot de passe oublié ?', style: AppTextStyles.link),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Se connecter',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _handleLogin,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.inputBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Pas encore de compte ?', style: AppTextStyles.body.copyWith(fontSize: 12.5)),
            ),
            const Expanded(child: Divider(color: AppColors.inputBorder)),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _openRegister,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: Text(
            _accountType == AccountType.university
                ? 'Créer un compte étudiant'
                : 'Créer un compte indépendant',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}

/// Traduit les codes d'erreur Appwrite en messages compréhensibles.
///
/// Un échec réseau et un mauvais mot de passe ne doivent pas être confondus :
/// c'est ce qui rendait le diagnostic impossible jusqu'ici.
String readableAuthError(AppwriteException e) {
  switch (e.code) {
    case 401:
      return 'Email ou mot de passe incorrect.';
    case 403:
      return 'Accès refusé : cette plateforme n\'est pas autorisée dans le projet '
          'Appwrite. Ajoutez son identifiant dans Overview → Platforms.';
    case 409:
      return 'Un compte existe déjà avec cet email. Connectez-vous, ou utilisez '
          '« Mot de passe oublié ».';
    case 429:
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    default:
      final message = e.message ?? '';
      if (message.contains('Failed host lookup') ||
          message.contains('Connection') ||
          message.contains('SocketException') ||
          message.contains('timed out')) {
        return 'Appwrite est injoignable. Vérifiez votre connexion internet et réessayez.';
      }
      return message.isEmpty ? 'Erreur Appwrite (code ${e.code}).' : message;
  }
}
