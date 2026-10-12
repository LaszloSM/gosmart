// lib/core/region.dart
// Alcance geográfico del MVP: Riohacha, Maicao y el corredor de la Troncal del Caribe.
import 'package:latlong2/latlong.dart';

abstract class GSRegion {
  /// Centro de Riohacha (Parque Padilla). Centro por defecto del mapa sin GPS.
  static const riohacha = LatLng(11.5444, -72.9072);

  /// Centro de Maicao.
  static const maicao = LatLng(11.3779, -72.2391);

  /// Caja que cubre Riohacha, Maicao, el corredor y el desvío por Albania–Cuestecitas.
  /// Formato Mapbox: minLng,minLat,maxLng,maxLat.
  static const bbox = '-73.30,10.90,-72.00,11.80';
}
