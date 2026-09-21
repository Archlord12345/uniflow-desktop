import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/app_info.dart';

void main() {
  test('AppInfo.version suit la version du pubspec', () {
    // Le desktop n'embarque pas `package_info_plus` : la version affichée dans
    // « À propos » est une constante, qui doit suivre `pubspec.yaml`.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim().split('+').first;
    expect(AppInfo.version, declared);
  });

  test('le pitch présente KERNEL FORGE comme une startup de Yaoundé I', () {
    expect(AppInfo.publisherPitch, contains('startup'));
    expect(AppInfo.publisherPitch, contains('Université de Yaoundé I'));
    expect(AppInfo.publisherPitch, contains('premier produit'));
    expect(AppInfo.publisherPitch, isNot(contains('communauté')));
  });
}
