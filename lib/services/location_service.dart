// lib/services/location_service.dart
// GPS del celular. Antes pedía una lectura de alta precisión con 10 s de
// límite y, si no llegaba (bajo techo, GPS frío), devolvía null: el mapa se
// quedaba sin punto y el planificador decía "Sin ubicación". Ahora:
//   1. revisa que el GPS esté prendido y que haya permiso (y dice cuál falta);
//   2. devuelve al instante la última posición conocida del sistema;
//   3. pide una lectura nueva con más paciencia y, si la alta precisión no
//      llega, se conforma con la de red (antenas/wifi);
//   4. publica cada posición en [positions] para que mapa, planificador y
//      viaje vean la misma.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Por qué no hay ubicación (para decirle al usuario qué hacer).
enum LocationIssue {
  /// El GPS del celular está apagado.
  serviceOff,

  /// No dio permiso (se puede volver a pedir).
  denied,

  /// Lo negó para siempre: solo se arregla en los ajustes de la app.
  deniedForever,

  /// Hay permiso y GPS, pero no llegó ninguna lectura.
  noFix,
}

String locationIssueText(LocationIssue issue) => switch (issue) {
      LocationIssue.serviceOff =>
        'El GPS está apagado. Actívalo para ver dónde estás.',
      LocationIssue.denied =>
        'GoSmart no tiene permiso de ubicación. Dalo para ver dónde estás.',
      LocationIssue.deniedForever =>
        'El permiso de ubicación está bloqueado. Actívalo en los ajustes de la app.',
      LocationIssue.noFix =>
        'Aún no llega la señal del GPS. Sal a cielo abierto o espera un momento.',
    };

class LocationService {
  /// Última posición conocida (para reportar al instante, sin esperar el GPS).
  LatLng? last;

  /// Cuándo llegó [last].
  DateTime? lastAt;

  /// Por qué falló la última vez (null = la última lectura funcionó).
  LocationIssue? lastIssue;

  /// true cuando hay permiso (el mapa de Google pinta su punto azul nativo).
  final hasPermission = ValueNotifier<bool>(false);

  final _positions = StreamController<LatLng>.broadcast();

  /// Cada posición nueva, venga de donde venga.
  Stream<LatLng> get positions => _positions.stream;

  Future<LatLng?>? _inFlight;

  LatLng _publish(Position p) {
    final at = LatLng(p.latitude, p.longitude);
    last = at;
    lastAt = DateTime.now();
    lastIssue = null;
    _positions.add(at);
    return at;
  }

  /// Revisa GPS y permiso. Con [request] pide el permiso si falta.
  /// Devuelve null si todo está bien, o el problema.
  Future<LocationIssue?> check({bool request = true}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        hasPermission.value = false;
        return LocationIssue.deniedForever;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        hasPermission.value = false;
        return LocationIssue.denied;
      }
      hasPermission.value = true;
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationIssue.serviceOff;
      }
      return null;
    } catch (_) {
      return LocationIssue.noFix;
    }
  }

  /// Abre lo que haga falta para arreglar [issue] (ajustes del GPS o de la app).
  Future<void> fix(LocationIssue issue) async {
    try {
      switch (issue) {
        case LocationIssue.serviceOff:
          await Geolocator.openLocationSettings();
        case LocationIssue.deniedForever:
          await Geolocator.openAppSettings();
        case LocationIssue.denied:
          await Geolocator.requestPermission();
        case LocationIssue.noFix:
          break;
      }
    } catch (_) {}
  }

  /// La posición actual del celular, o null (mira [lastIssue] para saber por
  /// qué). Si ya hay una lectura en curso, espera esa misma.
  Future<LatLng?> getCurrentPosition({bool request = true}) =>
      _inFlight ??= _read(request).whenComplete(() => _inFlight = null);

  Future<LatLng?> _read(bool request) async {
    final issue = await check(request: request);
    if (issue != null) {
      lastIssue = issue;
      return null;
    }
    // Una lectura reciente del sistema sirve para empezar ya.
    try {
      final known = await Geolocator.getLastKnownPosition();
      if (known != null) _publish(known);
    } catch (_) {}

    for (final s in const [
      (LocationAccuracy.high, Duration(seconds: 15)),
      (LocationAccuracy.medium, Duration(seconds: 12)),
    ]) {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: s.$1, timeLimit: s.$2),
        );
        return _publish(p);
      } catch (_) {
        // Sin lectura con esta precisión: probar la siguiente.
      }
    }
    if (last != null) return last;
    lastIssue = LocationIssue.noFix;
    return null;
  }

  // ── Seguimiento continuo ──────────────────────────────────────────────
  // Una sola suscripción al GPS para toda la app (geolocator en Android
  // reutiliza el primer stream y sus ajustes): el mapa, el aviso de alertas
  // y el modo conductor la comparten. En modo conductor sigue con la app en
  // segundo plano gracias a un servicio en primer plano (notificación fija),
  // como InDrive o Uber Driver.
  StreamSubscription<Position>? _platform;
  int _watchers = 0;
  bool _background = false;

  /// true mientras el conductor está conectado (servicio en primer plano).
  bool get backgroundTracking => _background;

  /// Una posición reciente (menos de [maxAge]) sin pedir al GPS, o la actual.
  Future<LatLng?> currentOrRecent({Duration maxAge = const Duration(seconds: 20)}) {
    final at = lastAt;
    if (last != null && at != null && DateTime.now().difference(at) < maxAge) {
      return Future.value(last);
    }
    return getCurrentPosition(request: false);
  }

  LocationSettings _settings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: _background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'GoSmart: estás conectado',
                notificationText:
                    'Compartiendo tu ubicación para recibir viajes cercanos.',
                notificationChannelName: 'Modo conductor',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  Future<void> _ensurePlatform({bool restart = false}) async {
    if (_platform != null && !restart) return;
    if (await check(request: false) != null) return;
    await _platform?.cancel();
    _platform = null;
    if (_watchers == 0 && !_background) return;
    try {
      _platform = Geolocator.getPositionStream(locationSettings: _settings())
          .listen(_publish, onError: (_) {
        _platform?.cancel();
        _platform = null;
      });
    } catch (_) {
      _platform = null;
    }
  }

  Future<void> _maybeStop() async {
    if (_watchers > 0 || _background) return;
    await _platform?.cancel();
    _platform = null;
  }

  /// Modo conductor: seguir la ubicación también en segundo plano.
  Future<void> setBackground(bool on) async {
    if (_background == on) return;
    _background = on;
    if (on || _watchers > 0) {
      await _ensurePlatform(restart: true);
    } else {
      await _maybeStop();
    }
  }

  /// Posición mientras te mueves. Sin permiso o sin GPS no emite nada; nunca
  /// lanza. [distanceFilter] se conserva por compatibilidad (el GPS
  /// compartido avisa cada 10 m).
  Stream<LatLng> watch({int distanceFilter = 40}) {
    StreamSubscription<LatLng>? sub;
    late final StreamController<LatLng> c;
    c = StreamController<LatLng>(
      onListen: () {
        _watchers++;
        sub = positions.listen(c.add);
        _ensurePlatform();
      },
      onCancel: () async {
        _watchers--;
        await sub?.cancel();
        await _maybeStop();
      },
    );
    return c.stream;
  }
}

final locationService = LocationService();
