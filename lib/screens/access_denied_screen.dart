import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/user_role.dart';
import '../router/route_guard.dart';
import '../widgets/motion.dart';

/// Écran « accès refusé », affiché quand une destination est demandée par un
/// chemin autre que le menu (fiche, restauration du dernier écran, lien) et
/// que la garde la refuse.
///
/// La raison est dite en clair : un écran qui disparaît sans explication
/// passe pour une panne, c'est exactement ce que le propriétaire ne veut plus.
class AccessDeniedScreen extends StatelessWidget {
  final AppDestination destination;
  final UserRole role;
  final AccountType accountType;
  final VoidCallback onBackHome;

  const AccessDeniedScreen({
    super.key,
    required this.destination,
    required this.role,
    required this.accountType,
    required this.onBackHome,
  });

  @override
  Widget build(BuildContext context) {
    return ResultView(
      success: false,
      title: 'Accès refusé',
      message: '${refusalReason(destination, role: role, accountType: accountType)}\n\n'
          'Vous êtes connecté avec le rôle ${role.label}'
          '${accountType == AccountType.personal ? ' (compte personnel)' : ''}. '
          '${role.scope}',
      actionLabel: 'Revenir à l\'accueil',
      onAction: onBackHome,
    );
  }
}
