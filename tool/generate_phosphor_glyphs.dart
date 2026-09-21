// Génère `lib/widgets/phosphor.dart` : les glyphes Phosphor que l'application
// utilise, en `IconData` ordinaires.
//
// Pourquoi ne pas importer `package:phosphor_flutter` directement ? Depuis
// Flutter 3.47, `IconData` est une classe `final` ; `phosphor_flutter` 2.1.0
// (dernière version publiée) fait `class PhosphorIconData extends IconData` et
// ne compile plus. Le paquet reste dans `pubspec.yaml` pour ses polices
// (`fontPackage: 'phosphor_flutter'`), mais aucun fichier Dart de l'application
// ne l'importe : ce script lit ses tables de codes et en recopie uniquement ce
// dont nous avons besoin, dans les trois graisses de la spécification
// (`docs/icones-uniflow.md`) — `duotone`, `fill`, `bold`.
//
// Usage : `dart run tool/generate_phosphor_glyphs.dart` depuis `uniflow-desktop`.
// À relancer quand un écran emploie une icône Phosphor qui n'est pas encore
// dans `lib/widgets/phosphor.dart` (l'analyseur le signale par un membre
// inconnu sur `PhosphorIconsDuotone`, `PhosphorIconsFill` ou
// `PhosphorIconsBold`).

import 'dart:convert';
import 'dart:io';

const _styles = ['Duotone', 'Fill', 'Bold'];
const _output = 'lib/widgets/phosphor.dart';

void main() {
  final root = _phosphorRoot();
  final names = _usedIconNames();
  final tables = {for (final style in _styles) style: _readTable(root, style)};

  final missing = <String>[];
  for (final name in names) {
    for (final style in _styles) {
      if (!tables[style]!.containsKey(name)) missing.add('$style.$name');
    }
  }
  if (missing.isNotEmpty) {
    stderr.writeln(
        'Icônes introuvables dans phosphor_flutter : ${missing.join(', ')}');
    exit(1);
  }

  File(_output).writeAsStringSync(_render(names, tables));
  // La CI du desktop refuse tout fichier non formaté (`dart format` à 80
  // colonnes) : on formate ici plutôt que de compter sur la personne qui relance.
  Process.runSync('dart', ['format', _output]);
  stdout.writeln(
      '${names.length} icônes × ${_styles.length} graisses écrites dans $_output');
}

/// Racine du paquet `phosphor_flutter`, lue dans la configuration de pub.
String _phosphorRoot() {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final entry = packages.firstWhere((p) => p['name'] == 'phosphor_flutter',
      orElse: () => throw StateError(
          'phosphor_flutter absent : lancer `flutter pub get`.'));
  return Uri.parse(entry['rootUri'] as String).toFilePath();
}

/// Les noms d'icônes référencés dans `lib/` et `test/`, hors le fichier généré.
Set<String> _usedIconNames() {
  final pattern = RegExp(r'PhosphorIcons(?:Duotone|Fill|Bold)\.([a-zA-Z0-9]+)');
  final names = <String>{};
  for (final dir in ['lib', 'test']) {
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.endsWith(_output)) {
        continue;
      }
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        names.add(match.group(1)!);
      }
    }
  }
  return names;
}

/// Une entrée de table : le code du glyphe, et pour le duotone le code du
/// calque secondaire.
class _Glyph {
  final int codePoint;
  final int? secondary;
  const _Glyph(this.codePoint, [this.secondary]);
}

Map<String, _Glyph> _readTable(String root, String style) {
  final source =
      File('$root/lib/src/phosphor_icons_${style.toLowerCase()}.dart')
          .readAsStringSync();
  final table = <String, _Glyph>{};
  if (style == 'Duotone') {
    // static const x = PhosphorDuotoneIconData(\n 0xe465,\n PhosphorIconData(0xe464, 'Duotone'),\n );
    final re = RegExp(
        r"static const (\w+) = PhosphorDuotoneIconData\(\s*(0x[0-9a-fA-F]+),\s*PhosphorIconData\((0x[0-9a-fA-F]+), 'Duotone'\),?\s*\)");
    for (final m in re.allMatches(source)) {
      table[m.group(1)!] =
          _Glyph(int.parse(m.group(2)!), int.parse(m.group(3)!));
    }
  } else {
    final re = RegExp(
        r"static const (\w+) = PhosphorFlatIconData\((0x[0-9a-fA-F]+), '" +
            style +
            r"'\)");
    for (final m in re.allMatches(source)) {
      table[m.group(1)!] = _Glyph(int.parse(m.group(2)!));
    }
  }
  return table;
}

String _hex(int value) => '0x${value.toRadixString(16)}';

String _render(Set<String> names, Map<String, Map<String, _Glyph>> tables) {
  final sorted = names.toList()..sort();
  final buffer = StringBuffer()
    ..writeln(
        '// GÉNÉRÉ par `tool/generate_phosphor_glyphs.dart` — ne pas modifier à la main.')
    ..writeln('//')
    ..writeln(
        '// Glyphes Phosphor utilisés par UniFlow, en `IconData` ordinaires. Les polices')
    ..writeln(
        '// viennent du paquet `phosphor_flutter` (déclaré dans `pubspec.yaml`), dont le')
    ..writeln(
        '// code Dart ne compile plus depuis que `IconData` est une classe `final`')
    ..writeln(
        '// (Flutter 3.47) : voir l\'en-tête du générateur pour le détail.')
    ..writeln('//')
    ..writeln(
        '// Les noms sont ceux de `phosphor_flutter` : le jour où le paquet est réparé,')
    ..writeln('// il suffit de remplacer l\'import de ce fichier par le sien.')
    ..writeln()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln("const String _package = 'phosphor_flutter';")
    ..writeln()
    ..writeln('/// Alias de compatibilité avec l\'API de `phosphor_flutter`.')
    ..writeln('typedef PhosphorIconData = IconData;')
    ..writeln();

  for (final style in _styles) {
    final family = 'Phosphor$style';
    buffer
      ..writeln('/// Graisse « ${style.toLowerCase()} » de Phosphor.')
      ..writeln('@staticIconProvider')
      ..writeln('class PhosphorIcons$style {')
      ..writeln('  PhosphorIcons$style._();')
      ..writeln();
    for (final name in sorted) {
      final glyph = tables[style]![name]!;
      buffer.writeln(
          '  static const IconData $name = IconData(${_hex(glyph.codePoint)}, '
          "fontFamily: '$family', fontPackage: _package, matchTextDirection: true);");
    }
    if (style == 'Duotone') {
      // Les calques secondaires sont des constantes : `IconData` exige un code
      // constant (`@mustBeConst`) pour que l'élagage des polices fonctionne.
      buffer
        ..writeln()
        ..writeln(
            '  /// Calque secondaire (le fond translucide) de chaque glyphe, par code.')
        ..writeln('  static const Map<int, IconData> secondaryByCodePoint = {');
      for (final name in sorted) {
        final glyph = tables[style]![name]!;
        buffer.writeln(
            '    ${_hex(glyph.codePoint)}: IconData(${_hex(glyph.secondary!)}, '
            "fontFamily: '$family', fontPackage: _package, matchTextDirection: true), // $name");
      }
      buffer
        ..writeln('  };')
        ..writeln()
        ..writeln(
            '  /// Le calque secondaire d\'un glyphe duotone, `null` pour toute autre icône.')
        ..writeln('  static IconData? secondaryOf(IconData icon) =>')
        ..writeln(
            "      icon.fontFamily == '$family' ? secondaryByCodePoint[icon.codePoint] : null;");
    }
    buffer
      ..writeln('}')
      ..writeln();
  }

  buffer.writeln(r'''
/// Rend un glyphe Phosphor ; pour un duotone, superpose le calque secondaire
/// (atténué et éventuellement recoloré) sous le calque principal — même API
/// que le `PhosphorIcon` de `phosphor_flutter`.
class PhosphorIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final double duotoneSecondaryOpacity;
  final Color? duotoneSecondaryColor;

  const PhosphorIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.duotoneSecondaryOpacity = 0.2,
    this.duotoneSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    final secondary = PhosphorIconsDuotone.secondaryOf(icon);
    if (secondary == null) return primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Le calque secondaire est purement décoratif : un seul libellé.
        ExcludeSemantics(
          child: Opacity(
            opacity: duotoneSecondaryOpacity,
            child: Icon(secondary, size: size, color: duotoneSecondaryColor ?? color),
          ),
        ),
        primary,
      ],
    );
  }
}''');
  return buffer.toString();
}
