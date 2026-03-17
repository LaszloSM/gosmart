// lib/core/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables loaded from .env
/// All values are non-nullable — app will throw on startup if missing.
class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get mapProvider => dotenv.env['MAP_PROVIDER'] ?? 'google';

  /// Gemini API key — kept for reference but no longer used by AiService.
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static String get mapboxToken => dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '';
}
