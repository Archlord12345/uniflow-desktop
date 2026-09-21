/// Identité de l'application affichée dans « À propos ».
///
/// La version est recopiée de `pubspec.yaml` (`version:`) : le desktop
/// n'embarque pas `package_info_plus`, et lire le pubspec à l'exécution est
/// impossible dans un binaire. Le test `app_info_test.dart` compare les deux
/// pour que la copie ne dérive pas.
class AppInfo {
  AppInfo._();

  static const String name = 'UniFlow';
  static const String version = '1.0.0';

  /// L'éditeur, tel que le propriétaire veut qu'il soit présenté
  /// (2026-09-21) : une startup, pas « une communauté tech ».
  static const String publisher = 'KERNEL FORGE';
  static const String publisherPitch =
      'KERNEL FORGE est une startup fondée à l’Université de Yaoundé I. '
      'UniFlow est son premier produit. Son ambition : devenir une entreprise '
      'de logiciel qui livre des projets pour des clients de tous secteurs, '
      'partout dans le monde.';
}
