// lib/models/geocode_suggestion.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// A single address suggestion returned by the Mapbox Geocoding API.
class GeocodeSuggestion {
  /// Short display name, e.g. "Parque de la 93".
  final String placeName;

  /// Full address string, e.g. "Parque de la 93, Bogotá, Colombia".
  final String fullAddress;

  /// Geographic coordinates.
  final LatLng latLng;

  /// Mapbox place_type[0] — one of: 'poi', 'address', 'neighborhood',
  /// 'locality', 'place', 'region', 'country', etc.
  final String featureType;

  const GeocodeSuggestion({
    required this.placeName,
    required this.fullAddress,
    required this.latLng,
    this.featureType = 'place',
  });

  /// Returns an icon that represents the kind of place.
  IconData get icon {
    switch (featureType) {
      case 'poi':
        return Icons.storefront_outlined;
      case 'address':
        return Icons.signpost_outlined;
      case 'neighborhood':
      case 'locality':
        return Icons.location_city_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }
}
