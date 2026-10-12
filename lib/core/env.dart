// lib/core/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables loaded from .env
/// All values are non-nullable — app will throw on startup if missing.
class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get mapProvider => dotenv.env['MAP_PROVIDER'] ?? 'google';

  /// Sentry DSN (opcional). Vacío = sin reporte de errores.
  static String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';

  /// Página pública que muestra un viaje compartido (`public_web/viaje.html`
  /// publicada en GitHub Pages). Vacío = el mensaje lleva solo el punto en el mapa.
  static String get shareBaseUrl => dotenv.env['SHARE_BASE_URL'] ?? '';
}
