// lib/models/geocode_suggestion.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Una sugerencia de lugar: del directorio propio o del proveedor externo.
class GeocodeSuggestion {
  /// Short display name, e.g. "Muelle Turístico".
  final String placeName;

  /// Full address string, e.g. "Parque Padilla, Riohacha, La Guajira".
  final String fullAddress;

  /// Coordenadas. null = sugerencia de Google aún sin resolver: se piden al
  /// elegirla (`placeSearch.resolve`), así Google cobra la sesión y no cada letra.
  final LatLng? latLng;

  /// Id de Google Places, para resolver las coordenadas al elegir.
  final String? placeId;

  /// Tipo de lugar: 'poi', 'address', 'neighborhood', 'locality', 'place'.
  final String featureType;

  /// true = viene del directorio propio (`places`), no del proveedor externo.
  final bool fromDirectory;

  /// true = coordenada aproximada, aún sin verificar en campo.
  final bool approximate;

  const GeocodeSuggestion({
    required this.placeName,
    required this.fullAddress,
    required this.latLng,
    this.placeId,
    this.featureType = 'place',
    this.fromDirectory = false,
    this.approximate = false,
  });

  GeocodeSuggestion withLocation(LatLng at, {String? address}) =>
      GeocodeSuggestion(
        placeName: placeName,
        fullAddress: (address == null || address.isEmpty) ? fullAddress : address,
        latLng: at,
        placeId: placeId,
        featureType: featureType,
        fromDirectory: fromDirectory,
        approximate: approximate,
      );

  /// Returns an icon that represents the kind of place.
  IconData get icon {
    switch (featureType) {
      case 'poi':
        return Icons.storefront_rounded;
      case 'address':
        return Icons.signpost_rounded;
      case 'neighborhood':
      case 'locality':
        return Icons.location_city_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}
