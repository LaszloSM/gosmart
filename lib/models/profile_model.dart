import 'package:intl/intl.dart';

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final int ecoPoints;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.ecoPoints = 0,
  });

  factory ProfileModel.fromMap(
    Map<String, dynamic> map, {
    required String email,
  }) {
    return ProfileModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      email: email,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      ecoPoints: (map['eco_points'] as num?)?.toInt() ?? 0,
    );
  }

  ProfileModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    int? ecoPoints,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      ecoPoints: ecoPoints ?? this.ecoPoints,
    );
  }

  String get formattedEcoPoints =>
      NumberFormat('#,##0', 'en_US').format(ecoPoints);
}
