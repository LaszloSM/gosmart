// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Última posición conocida (para reportar al instante, sin esperar el GPS).
  LatLng? last;

  /// Returns the device's current GPS position.
  /// Returns null if permission is denied, timed out, or any error occurs.
  /// Callers are responsible for their own fallback (e.g. default to GSRegion.riohacha).
  Future<LatLng?> getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return last = LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Posición mientras te mueves (cada [distanceFilter] metros). Sin permiso
  /// o sin GPS no emite nada; nunca lanza.
  Stream<LatLng> watch({int distanceFilter = 40}) async* {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      await for (final p in Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        ),
      )) {
        yield last = LatLng(p.latitude, p.longitude);
      }
    } catch (_) {
      return;
    }
  }
}

final locationService = LocationService();
