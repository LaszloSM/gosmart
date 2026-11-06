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

  /// Posición mientras te mueves (cada [distanceFilter] metros). Sin permiso
  /// o sin GPS no emite nada; nunca lanza.
  Stream<LatLng> watch({int distanceFilter = 40}) async* {
    try {
      if (await check(request: false) != null) return;
      await for (final p in Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        ),
      )) {
        yield _publish(p);
      }
    } catch (_) {
      return;
    }
  }
}

final locationService = LocationService();
