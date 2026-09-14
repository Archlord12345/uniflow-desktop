import 'dart:io';

/// Résolution d'adresses et de ports pour l'hébergement d'une réunion.
///
/// Une réunion se déroule sur le réseau local de l'hôte : il faut donc lui
/// trouver une adresse joignable par les autres machines, et non `localhost`.
class ConferenceNetwork {
  const ConferenceNetwork._();

  /// Adresse IPv4 de la machine sur son réseau local.
  ///
  /// Écarte les adresses de bouclage et les adresses lien-local (169.254.x.x,
  /// que Windows attribue quand le DHCP n'a pas répondu) : aucune des deux
  /// n'est joignable depuis un autre poste. Préfère les interfaces dont le nom
  /// évoque une connexion réelle (ethernet, wi-fi) quand il y en a plusieurs.
  ///
  /// Renvoie `null` si la machine n'est sur aucun réseau — l'appelant doit
  /// alors le signaler plutôt que d'annoncer une adresse inutilisable.
  static Future<String?> localIpAddress() async {
    final List<NetworkInterface> interfaces;
    try {
      // Le filtrage des adresses inutilisables est fait par [_isUsableIpv4]
      // plutôt que par les options de `list` : on garde ainsi la même règle
      // pour le bouclage, le lien-local et l'adresse indéterminée.
      interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
    } on SocketException {
      return null;
    }

    final candidates = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address;
        if (_isUsableIpv4(value)) candidates.add(value);
      }
    }
    if (candidates.isEmpty) return null;

    return candidates.first;
  }

  /// Vrai pour une adresse IPv4 privée ou publique utilisable sur un LAN.
  static bool _isUsableIpv4(String address) {
    if (address.isEmpty) return false;
    if (address == '0.0.0.0') return false;
    if (address.startsWith('127.')) return false;
    if (address.startsWith('169.254.')) return false;
    return true;
  }

  /// Cherche un port TCP libre à partir de [preferred].
  ///
  /// Un port fixe conviendrait la plupart du temps, mais l'API de jonction
  /// doit pouvoir démarrer même si un autre logiciel occupe déjà le port par
  /// défaut : on essaie une plage courte avant d'abandonner.
  static Future<int> findFreePort(int preferred, {int attempts = 20}) async {
    for (var port = preferred; port < preferred + attempts; port++) {
      if (await isPortFree(port)) return port;
    }
    throw SocketException(
      'Aucun port libre entre $preferred et ${preferred + attempts - 1}.',
    );
  }

  /// Vrai si [port] peut être écouté sur toutes les interfaces.
  static Future<bool> isPortFree(int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
    }
  }
}
