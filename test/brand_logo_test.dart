// Vérifie la marque affichée dans l'application.
//
// Symptôme d'origine : `UniFlowIcon` affichait `assets/images/logo.png`, le
// logotype horizontal 1711×531, avec `BoxFit.cover` dans un carré de `size`.
// L'image était mise à l'échelle sur la hauteur puis rognée sur la largeur :
// le mot « UniFlow » disparaissait et seul un fragment central de l'écusson
// restait visible.
//
// Ces deux tests tiennent les propriétés qui l'empêchent : un écusson carré,
// affiché sans rognage.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/widgets/uniflow_logo.dart';

/// L'écusson carré — surtout pas le logotype horizontal.
const String _ecusson = 'assets/brand/uniflow_marque.png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("UniFlowIcon affiche l'écusson carré, sans le rogner",
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: UniFlowIcon(size: 40))),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    // `cacheWidth` enveloppe l'asset dans un `ResizeImage` : c'est voulu,
    // l'écusson 512 px réduit sans rééchantillonnage sortait crénelé.
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    final asset = (provider as ResizeImage).imageProvider;
    expect(
      (asset as AssetImage).assetName,
      _ecusson,
      reason: 'le logotype horizontal rogné dans un carré ne doit pas revenir',
    );
    expect(image.filterQuality, FilterQuality.high);
    // `cover` rognait l'image ; `contain` la réduit sans jamais la tronquer.
    expect(image.fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });

  test('l\'écusson est carré, donc un carré ne le rogne pas', () async {
    // `rootBundle.load` échoue si l'asset n'est pas déclaré dans le pubspec :
    // ce test vérifie donc aussi que `assets/brand/` est bien embarqué.
    final data = await rootBundle.load(_ecusson);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    addTearDown(image.dispose);

    expect(
      image.width,
      image.height,
      reason: 'un écusson non carré serait rogné par UniFlowIcon',
    );
  });
}
