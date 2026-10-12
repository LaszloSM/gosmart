// lib/core/auth_errors.dart
// Mensajes de error de autenticación en lenguaje claro. Nunca se muestra la
// excepción técnica al usuario.
import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyAuthError(Object e) {
  final msg = e is AuthException ? e.message.toLowerCase() : '';
  if (msg.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Confirma tu correo con el enlace que te enviamos.';
  }
  if (msg.contains('already registered') || msg.contains('already exists')) {
    return 'Ya hay una cuenta con ese correo. Entra con tu contraseña.';
  }
  if (msg.contains('token has expired') || msg.contains('invalid otp') ||
      msg.contains('otp')) {
    return 'El código no es válido o ya venció. Pide uno nuevo.';
  }
  if (msg.contains('password')) {
    return 'La contraseña no cumple los requisitos (mínimo 8 caracteres).';
  }
  if (msg.contains('rate limit') || msg.contains('too many')) {
    return 'Hiciste muchos intentos. Espera unos minutos.';
  }
  return 'No pudimos conectarnos. Revisa tu señal e intenta de nuevo.';
}

/// Celular colombiano a formato E.164 (+57…), que exige el envío de SMS.
/// "300 123 4567" → "+573001234567". Si ya trae +, se respeta.
String normalizeColombianPhone(String input) {
  final trimmed = input.trim();
  if (trimmed.startsWith('+')) {
    return '+${trimmed.replaceAll(RegExp(r'\D'), '')}';
  }
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('57')) return '+$digits';
  return '+57$digits';
}
