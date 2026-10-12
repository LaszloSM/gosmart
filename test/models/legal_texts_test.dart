// test/models/legal_texts_test.dart
// Ley 1581: la política debe cubrir lo mínimo del art. 13 del Decreto 1377.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/legal/legal_texts.dart';

void main() {
  final all = privacyPolicy.sections.map((s) => '${s.title} ${s.body}').join(' ');

  test('la política nombra responsable, finalidad, derechos y la SIC', () {
    expect(all, contains('Responsable'));
    expect(all, contains('Para qué'));
    expect(all, contains('suprimir'));
    expect(all, contains('revocar'));
    expect(all, contains('Superintendencia de Industria y Comercio'));
  });

  test('dice que los datos sensibles son opcionales', () {
    expect(all, contains('sensibles'));
    expect(all, contains('opcional'));
  });

  test('los términos no prometen que el SOS siempre llegue', () {
    final t = termsOfUse.sections.map((s) => s.body).join(' ');
    expect(t, contains('no es un servicio de emergencias'));
    expect(t, contains('no son dinero'));
  });

  test('el borrador marca a la vista lo que falta', () {
    expect(all, contains('[PENDIENTE'));
  });
}
