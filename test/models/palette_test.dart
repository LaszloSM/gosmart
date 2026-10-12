import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/theme/design_tokens.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => GSColors.apply(Brightness.light));

  test('GSColors sigue la paleta activa', () {
    GSColors.apply(Brightness.dark);
    expect(GSColors.isDark, isTrue);
    expect(GSColors.background, GSPalette.dark.background);
    GSColors.apply(Brightness.light);
    expect(GSColors.surface, GSPalette.light.surface);
  });

  for (final entry in {'día': GSPalette.light, 'noche': GSPalette.dark}.entries) {
    test('texto principal ≥ 7:1 (${entry.key})', () {
      final p = entry.value;
      expect(_contrast(p.text, p.background), greaterThanOrEqualTo(7));
      expect(_contrast(p.textMuted, p.surface), greaterThanOrEqualTo(7));
      expect(_contrast(p.brand, p.surface), greaterThanOrEqualTo(7));
      expect(_contrast(p.onBrand, p.brand), greaterThanOrEqualTo(7));
      expect(_contrast(p.onShell, p.shell), greaterThanOrEqualTo(7));
      for (final road in [p.roadOpen, p.roadCaution, p.roadClosed, p.roadUnknown]) {
        expect(_contrast(road, p.surface), greaterThanOrEqualTo(7));
      }
    });
  }

  test('el tema nocturno es oscuro y usa la carrocería en la barra', () {
    final dark = AppTheme.dark;
    expect(dark.brightness, Brightness.dark);
    expect(dark.appBarTheme.backgroundColor, GSPalette.dark.shell);
  });
}
