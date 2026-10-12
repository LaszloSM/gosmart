// lib/core/telemetry.dart
// Reporte de errores con Sentry (plan gratis). Si SENTRY_DSN está vacío no se
// envía nada y la app funciona igual (desarrollo local, tests).
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'env.dart';

abstract class Telemetry {
  // Sin .env cargado (pruebas) no hay Sentry, en vez de fallar.
  static bool get enabled =>
      dotenv.isInitialized && Env.sentryDsn.isNotEmpty;

  /// Inicia Sentry alrededor de [appRunner], o lo ejecuta directo si no hay DSN.
  static Future<void> init(Future<void> Function() appRunner) async {
    if (!enabled) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        // Sin datos personales por defecto (Ley 1581).
        options.sendDefaultPii = false;
        options.tracesSampleRate = 0.0;
      },
      appRunner: appRunner,
    );
  }

  /// Un servicio externo falló y la app siguió en modo degradado (decisión D8).
  /// [service]: 'groq' | 'google_places' | 'google_routes' | 'supabase' ...
  static void degraded(String service, String code) {
    debugPrint('[Telemetry] degradado: $service ($code)');
    if (!enabled) return;
    Sentry.captureMessage(
      'degraded:$service',
      level: SentryLevel.warning,
      withScope: (scope) {
        scope.setTag('service', service);
        scope.setTag('code', code);
      },
    );
  }
}
