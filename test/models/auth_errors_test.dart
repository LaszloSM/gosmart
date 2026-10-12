import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/auth_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('normalizeColombianPhone', () {
    expect(normalizeColombianPhone('300 123 4567'), '+573001234567');
    expect(normalizeColombianPhone('3001234567'), '+573001234567');
    expect(normalizeColombianPhone('573001234567'), '+573001234567');
    expect(normalizeColombianPhone('+57 300-123-4567'), '+573001234567');
  });

  test('friendlyAuthError no filtra la excepción técnica', () {
    expect(friendlyAuthError(const AuthException('Invalid login credentials')),
        'Correo o contraseña incorrectos.');
    final generic = friendlyAuthError(Exception('SocketException: boom'));
    expect(generic.contains('Socket'), isFalse);
  });
}
