// tool/screenshots/shot_util.dart
// Fuentes reales y tamaño de teléfono para capturas de revisión de diseño.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadFonts() async {
  final b = FontLoader('Figtree');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    b.addFont(rootBundle.load('assets/fonts/Figtree-$f.ttf'));
  }
  await b.load();
  final i = FontLoader('MaterialIcons');
  i.addFont(File('/opt/flutter-sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
      .readAsBytes().then((x) => ByteData.view(x.buffer)));
  await i.load();
}

void phone(WidgetTester t, {double scale = 1}) {
  t.view.physicalSize = const Size(360 * 2, 780 * 2);
  t.view.devicePixelRatio = 2;
  t.platformDispatcher.textScaleFactorTestValue = scale;
}
