import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_destination.dart';

/// Destination courante de la coquille, partagée pour que n'importe quel écran
/// (une fiche, un bouton « voir mes devoirs », une action rapide du tableau de
/// bord) puisse demander une navigation sans tenir la coquille par la main.
///
/// Vivait dans `main_shell.dart` ; sorti pour que le tableau de bord puisse
/// naviguer sans importer la coquille qui l'affiche (cycle d'imports).
final currentDestinationProvider =
    StateProvider<AppDestination?>((ref) => null);
