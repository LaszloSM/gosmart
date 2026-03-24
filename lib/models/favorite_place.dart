// lib/models/favorite_place.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/design_tokens.dart';
import 'geocode_suggestion.dart';

enum FavoritePlaceType { home, work, custom }

class FavoritePlace {
  final String id;
  final String userId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final FavoritePlaceType type;
  final String icon;
  final int useCount;
  final DateTime createdAt;

  const FavoritePlace({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.icon = 'location_on',
    this.useCount = 0,
    required this.createdAt,
  });

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: _typeFrom(json['type'] as String? ?? 'custom'),
      icon: json['icon'] as String? ?? 'location_on',
      useCount: json['use_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static FavoritePlaceType _typeFrom(String v) => switch (v) {
        'home' => FavoritePlaceType.home,
        'work' => FavoritePlaceType.work,
        _ => FavoritePlaceType.custom,
      };

  LatLng get latLng => LatLng(latitude, longitude);

  GeocodeSuggestion toSuggestion() => GeocodeSuggestion(
        placeName: name,
        fullAddress: address,
        latLng: latLng,
      );

  IconData get iconData => switch (type) {
        FavoritePlaceType.home => Icons.home_rounded,
        FavoritePlaceType.work => Icons.work_rounded,
        FavoritePlaceType.custom => Icons.location_on_rounded,
      };

  Color get color => switch (type) {
        FavoritePlaceType.home => GSColors.accent,
        FavoritePlaceType.work => GSColors.accentAlt,
        FavoritePlaceType.custom => GSColors.textSecondary,
      };

  String get typeLabel => switch (type) {
        FavoritePlaceType.home => 'Casa',
        FavoritePlaceType.work => 'Trabajo',
        FavoritePlaceType.custom => 'Favorito',
      };
}
