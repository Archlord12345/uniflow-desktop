import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/motion.dart';
import 'login_screen.dart';

/// Réinitialisation du mot de passe en deux temps, sans quitter le desktop.
///
/// Appwrite envoie un email dont le lien pointe vers le client web
/// (`/reset-password?userId=…&secret=…`). Le desktop n'ayant pas de lien
/// profond, l'utilisateur colle ce lien dans la seconde étape : on en extrait
/// les deux paramètres et on termine la réinitialisation ici. Le lien web
/// reste utilisable tel quel si la page existe côté web.
Future<void> showForgotPasswordDialog(BuildContext context,
    {String initialEmail = ''}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  final String initialEmail;
  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

enum _Step { request, complete, done }

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  late final _emailController =
      TextEditingController(text: widget.initialEmail);
  final _linkController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.request;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _linkController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordRecovery(_emailController.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.complete;
      });
    } on AppwriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == 404
            ? 'Aucun compte ne porte cet email.'
            : readableAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Envoi impossible : $e';
      });
    }
  }

  Future<void> _complete() async {
    final parsed = parseRecoveryLink(_linkController.text);
    if (parsed == null) {
      setState(
          () => _error = 'Le lien collé ne contient pas userId et secret.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error =
          'Le nouveau mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completePasswordRecovery(
            userId: parsed.userId,
            secret: parsed.secret,
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.done;
      });
    } on AppwriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == 401
            ? 'Le lien a expiré ou a déjà servi. Demandez un nouvel email.'
            : readableAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(switch (_step) {
        _Step.request => 'Mot de passe oublié',
        _Step.complete => 'Terminer la réinitialisation',
        _Step.done => 'Mot de passe modifié',
      }),
      // Largeur suivant la fenêtre : 420 px fixes faisaient déborder le
      // dialogue sur une fenêtre étroite et paraissaient minuscules en 4K.
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, 520.0),
        child: AnimatedSwitcher(
          duration: kMotionMedium,
          transitionBuilder: pageTransition,
          child: KeyedSubtree(key: ValueKey(_step), child: _body()),
        ),
      ),
      actions: switch (_step) {
        _Step.request => [
            AppButton.ghost(
                label: 'Annuler',
                onPressed: _busy ? null : () => Navigator.pop(context)),
            AppButton.secondary(
              label: 'J\'ai déjà le lien',
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.complete),
            ),
            AppButton(
              label: 'Envoyer l\'email',
              loading: _busy,
              onPressed: _busy ? null : _sendEmail,
            ),
          ],
        _Step.complete => [
            AppButton.secondary(
                label: 'Annuler',
                onPressed: _busy ? null : () => Navigator.pop(context)),
            AppButton(
              label: 'Changer le mot de passe',
              loading: _busy,
              onPressed: _busy ? null : _complete,
            ),
          ],
        _Step.done => [
            AppButton(
                label: 'Se connecter',
                onPressed: () => Navigator.pop(context)),
          ],
      },
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.request:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nous envoyons un email contenant un lien de réinitialisation. '
              'Collez ensuite ce lien ici pour choisir un nouveau mot de passe.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email du compte'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!)
            ],
          ],
        );
      case _Step.complete:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ouvrez l\'email reçu, copiez le lien qu\'il contient et collez-le '
              'ci-dessous, puis choisissez un nouveau mot de passe.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _linkController,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Lien reçu par email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmer le mot de passe'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!)
            ],
          ],
        );
      case _Step.done:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCheck(size: 64),
            SizedBox(height: 14),
            Text(
              'Votre mot de passe a été changé. Connectez-vous avec le nouveau.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        );
    }
  }
}
