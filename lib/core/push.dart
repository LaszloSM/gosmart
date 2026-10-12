// lib/core/push.dart
// Notificaciones push (FCM), opcionales: si el proyecto no tiene Firebase
// configurado (google-services.json), init() no hace nada y la app sigue igual.
// Con sesión, el token del teléfono se registra en `push_tokens` (018).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase_client.dart';

abstract class Push {
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] sin Firebase configurado: $e');
      return;
    }
    _ready = true;
    final fcm = FirebaseMessaging.instance;
    // Android 13+ pide el permiso; antes se concede solo.
    await fcm.requestPermission();
    fcm.onTokenRefresh.listen(_register);
    GoSmartSupabase.client.auth.onAuthStateChange.listen((s) async {
      if (s.session != null) _register(await fcm.getToken());
    });
    _register(await fcm.getToken());
  }

  static Future<void> _register(String? token) async {
    if (token == null || GoSmartSupabase.client.auth.currentSession == null) return;
    try {
      await GoSmartSupabase.client.rpc('register_push_token',
          params: {'p_token': token, 'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase()});
    } catch (e) {
      debugPrint('[Push] no se registró el token: $e');
    }
  }
}
