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
  /// n'est joignable depuis un autre poste. Quand il y a plusieurs interfaces,
  /// la première du classement de [rankAddresses] est retenue.
  ///
  /// Renvoie `null` si la machine n'est sur aucun réseau — l'appelant doit
  /// alors le signaler plutôt que d'annoncer une adresse inutilisable.
  static Future<String?> localIpAddress() async {
    final candidates = await localIpCandidates();
    return candidates.isEmpty ? null : candidates.first.address;
  }

  /// Toutes les adresses IPv4 utilisables de la machine, de la plus probable
  /// à la moins probable pour joindre l'hôte depuis un autre poste.
  ///
  /// L'écran de la salle les propose à l'hôte : sur une machine qui a à la
  /// fois du Wi-Fi et de l'Ethernet, lui seul sait sur quel réseau sont ses
  /// participants.
  static Future<List<LocalAddress>> localIpCandidates() async {
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
      return const [];
    }

    return rankAddresses([
      for (final interface in interfaces)
        for (final address in interface.addresses)
          LocalAddress(interfaceName: interface.name, address: address.address),
    ]);
  }

  /// Classe des adresses candidates, de la plus à la moins joignable.
  ///
  /// L'ancienne règle (« la première interface listée ») annonçait sur une
  /// machine de développement l'adresse du pont Docker `172.17.0.1` : elle
  /// vient souvent avant la carte réseau dans la liste du système et n'est
  /// joignable par personne. Les ponts et interfaces virtuelles (Docker,
  /// libvirt, VirtualBox, VMware, tunnels VPN) passent donc derrière les
  /// cartes physiques ; à égalité, une adresse privée (192.168, 10, 172.16-31)
  /// passe devant une adresse publique, plus rare sur un LAN de classe.
  static List<LocalAddress> rankAddresses(Iterable<LocalAddress> candidates) {
    final usable = [
      for (final candidate in candidates)
        if (_isUsableIpv4(candidate.address)) candidate,
    ];
    // Tri stable : deux adresses de même rang restent dans l'ordre du système.
    final indexed = usable.asMap().entries.toList()
      ..sort((a, b) {
        final byRank = _rank(a.value).compareTo(_rank(b.value));
        return byRank != 0 ? byRank : a.key.compareTo(b.key);
      });
    return [for (final entry in indexed) entry.value];
  }

  /// Rang d'une adresse : plus il est bas, plus l'adresse est probable.
  static int _rank(LocalAddress candidate) {
    var rank = 0;
    if (candidate.isVirtualInterface) rank += 100;
    if (!candidate.isPrivate) rank += 10;
    if (candidate.isWireless || candidate.isWired) rank -= 1;
    return rank;
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

/// Une adresse IPv4 de la machine et l'interface qui la porte.
class LocalAddress {
  final String interfaceName;
  final String address;

  const LocalAddress({required this.interfaceName, required this.address});

  /// Préfixes de nom des interfaces créées par des logiciels (conteneurs,
  /// machines virtuelles, VPN) : leurs adresses ne sont pas sur le réseau de
  /// la salle. Comparés en minuscules ; Windows nomme ses cartes en clair
  /// (« Ethernet », « Wi-Fi », « vEthernet (WSL) »).
  static const List<String> _virtualPrefixes = [
    'docker',
    'br-',
    'virbr',
    'veth',
    'vmnet',
    'vboxnet',
    'vethernet',
    'tun',
    'tap',
    'wg',
    'zt',
    'tailscale',
    'utun',
    'lxc',
    'lxd',
    'cni',
    'flannel',
    'ham',
    'nordlynx',
  ];

  bool get isVirtualInterface {
    final name = interfaceName.toLowerCase();
    return _virtualPrefixes.any(name.startsWith);
  }

  bool get isWireless {
    final name = interfaceName.toLowerCase();
    return name.startsWith('wl') ||
        name.contains('wi-fi') ||
        name.contains('wifi');
  }

  bool get isWired {
    final name = interfaceName.toLowerCase();
    return name.startsWith('en') ||
        name.startsWith('eth') ||
        name.startsWith('ethernet');
  }

  /// Plages privées RFC 1918, celles d'un réseau local ordinaire.
  bool get isPrivate {
    final parts = address.split('.');
    if (parts.length != 4) return false;
    final first = int.tryParse(parts[0]) ?? -1;
    final second = int.tryParse(parts[1]) ?? -1;
    if (first == 10) return true;
    if (first == 192 && second == 168) return true;
    if (first == 172 && second >= 16 && second <= 31) return true;
    return false;
  }

  /// Libellé pour un menu : « 192.168.1.20 (wlan0) ».
  String get label => '$address ($interfaceName)';

  @override
  bool operator ==(Object other) =>
      other is LocalAddress &&
      other.interfaceName == interfaceName &&
      other.address == address;

  @override
  int get hashCode => Object.hash(interfaceName, address);

  @override
  String toString() => label;
}
