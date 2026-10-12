// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase_client.dart';
import 'core/sync_queue.dart';
import 'core/telemetry.dart';
import 'router/app_router.dart';
import 'services/corridor_service.dart';
import 'services/safety_service.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await GoSmartSupabase.initialize();

  // Lo que quedó pendiente sin señal se reenvía al abrir y al volver a la app.
  safetyService.registerSyncHandlers(syncQueue);
  corridorService.registerSyncHandlers(syncQueue);
  syncQueue.flush();
  AppLifecycleListener(
    onResume: () => syncQueue.flush(),
  );

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Telemetry.init(() async {
    runApp(
      // ProviderScope enables Riverpod throughout the app
      const ProviderScope(
        child: GoSmartApp(),
      ),
    );
  });
}

class GoSmartApp extends ConsumerWidget {
  const GoSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'GoSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Noche: esquema propio que sigue al sistema (viajes nocturnos).
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // GSColors lee la paleta activa. Al cambiar día/noche se aplica y se
      // reconstruye el árbol (muchos widgets son const y no se repintarían).
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        GSColors.apply(brightness);
        return KeyedSubtree(
          key: ValueKey(brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
      locale: const Locale('es', 'CO'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('en', 'US'),
      ],
    );
  }
}
