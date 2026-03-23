// lib/services/geocoding_service.dart
// Mapbox Geocoding API v5 — address search for Colombia.
// Uses the same MAPBOX_PUBLIC_TOKEN as DirectionsService and TileLayer.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/env.dart';
import '../models/geocode_suggestion.dart';

class GeocodingService {
  static const _base = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Returns up to 8 address suggestions for [query].
  ///
  /// [proximity]: optional LatLng to bias results toward user location.
  /// Returns [] if token is empty, query has fewer than 2 chars, or any error.
  Future<List<GeocodeSuggestion>> search(
    String query, {
    LatLng? proximity,
  }) async {
    final token = Env.mapboxToken;
    if (token.isEmpty || query.trim().length < 2) return [];

    try {
      final encoded = Uri.encodeComponent(query.trim());
      var url = '$_base/$encoded.json'
          '?access_token=$token'
          '&country=co'
          '&language=es'
          '&limit=8'
          '&autocomplete=true'
          '&types=address,poi,neighborhood,locality,place'
          '&bbox=-81.7,1.0,-66.8,13.4';
      if (proximity != null) {
        url += '&proximity=${proximity.longitude},${proximity.latitude}';
      }

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('[GeocodingService] ${res.statusCode}: ${res.body}');
        return [];
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      return features.map((f) {
        final coords = f['geometry']['coordinates'] as List;
        final placeTypes = f['place_type'] as List? ?? [];
        final featureType =
            placeTypes.isNotEmpty ? placeTypes[0] as String : 'place';
        return GeocodeSuggestion(
          placeName: f['text'] as String? ?? '',
          fullAddress: f['place_name'] as String? ?? '',
          latLng: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
          featureType: featureType,
        );
      }).toList();
    } catch (e) {
      debugPrint('[GeocodingService] search error: $e');
      return [];
    }
  }

  /// Geocodes a single address string. Returns the first result or null.
  Future<GeocodeSuggestion?> geocodeFirst(
    String query, {
    LatLng? proximity,
  }) async {
    final results = await search(query, proximity: proximity);
    return results.isEmpty ? null : results.first;
  }
}

final geocodingService = GeocodingService();
