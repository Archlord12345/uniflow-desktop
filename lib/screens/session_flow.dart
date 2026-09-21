import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../widgets/motion.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Déconnecte puis remplace toute la pile par l'écran de connexion.
///
/// Un seul point d'entrée pour la barre latérale, le profil, les paramètres
/// et l'expiration de session : chacun faisait son propre `deleteSession`
/// et l'un d'eux oubliait la réunion en cours.
Future<void> signOutToLogin(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  await ref.read(sessionControllerProvider).signOut();
  ref.read(currentDestinationProvider.notifier).state = null;
  if (!context.mounted) return;
  navigator.pushAndRemoveUntil(softRoute(const LoginScreen()), (_) => false);
}

/// Bouton « Se déconnecter » partagé, pour que le libellé et le geste soient
/// les mêmes partout.
class SignOutButton extends ConsumerWidget {
  final bool compact;
  final Color? color;
  const SignOutButton({super.key, this.compact = false, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = color ?? AppColors.danger;
    if (compact) {
      return IconButton(
        tooltip: 'Se déconnecter',
        onPressed: () => signOutToLogin(context, ref),
        icon: Icon(Icons.logout_rounded, color: tint, size: 20),
      );
    }
    return TextButton.icon(
      onPressed: () => signOutToLogin(context, ref),
      style: TextButton.styleFrom(foregroundColor: tint),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Se déconnecter'),
    );
  }
}

/// Ouvre la confirmation en deux étapes puis supprime le compte.
///
/// Étape 1 : mot de passe, vérifié par le serveur. Étape 2 : recopie du mot
/// [kDeleteAccountKeyword]. Le succès affiche un écran animé, qui renvoie à
/// l'accueil ; un refus reste dans le dialogue avec le message du serveur.
Future<void> showDeleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  final result = await showDialog<DeleteAccountResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (result == null || !result.succeeded || !context.mounted) return;

  ref.read(currentDestinationProvider.notifier).state = null;
  navigator.pushAndRemoveUntil(
    softRoute(
      Scaffold(
        backgroundColor: AppColors.background,
        body: ResultView(
          success: true,
          title: 'Compte supprimé',
          message:
              'Vos données de compte ont été effacées. Merci d\'avoir utilisé UniFlow.',
          actionLabel: 'Revenir à l\'accueil',
          onAction: () => navigator.pushAndRemoveUntil(
            softRoute(const LoginScreen()),
            (_) => false,
          ),
        ),
      ),
    ),
    (_) => false,
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  final _keyword = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_step == 0) {
      if (_password.text.isEmpty) {
        setState(() => _error = 'Saisissez votre mot de passe.');
        return;
      }
      setState(() {
        _step = 1;
        _error = null;
      });
      return;
    }
    if (_keyword.text.trim() != kDeleteAccountKeyword) {
      setState(
          () => _error = 'Recopiez exactement le mot $kDeleteAccountKeyword.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(sessionControllerProvider)
        .deleteOwnAccount(password: _password.text);
    if (!mounted) return;
    if (result.succeeded) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.message;
      // Mot de passe faux : on revient à la première étape pour le ressaisir.
      if (result.outcome == DeleteAccountOutcome.wrongPassword) {
        _step = 0;
        _password.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          SizedBox(width: 10),
          Expanded(child: Text('Supprimer mon compte')),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: AnimatedSwitcher(
          duration: kMotionMedium,
          transitionBuilder: pageTransition,
          child: Column(
            key: ValueKey(_step),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _step == 0
                    ? 'Cette action est définitive : votre profil, vos notes et vos messages seront effacés. Confirmez d\'abord votre mot de passe.'
                    : 'Dernière étape : recopiez le mot $kDeleteAccountKeyword pour confirmer.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 14),
              if (_step == 0)
                TextField(
                  key: const Key('delete-account-password'),
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  onSubmitted: (_) => _submit(),
                )
              else
                TextField(
                  key: const Key('delete-account-keyword'),
                  controller: _keyword,
                  autofocus: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: 'Tapez $kDeleteAccountKeyword'),
                  onSubmitted: (_) => _submit(),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
          label: 'Annuler',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.danger(
          key: const Key('delete-account-confirm'),
          label: _step == 0 ? 'Continuer' : 'Supprimer définitivement',
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
