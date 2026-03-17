import 'package:intl/intl.dart';

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final int ecoPoints;
  final String? cedula;
  final String? city;
  final DateTime? birthDate;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.ecoPoints = 0,
    this.cedula,
    this.city,
    this.birthDate,
  });

  factory ProfileModel.fromMap(
    Map<String, dynamic> map, {
    required String email,
  }) {
    DateTime? parsedBirthDate;
    final rawDate = map['birth_date'] as String?;
    if (rawDate != null) {
      parsedBirthDate = DateTime.tryParse(rawDate);
    }

    return ProfileModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      email: email,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      ecoPoints: (map['eco_points'] as num?)?.toInt() ?? 0,
      cedula: map['cedula'] as String?,
      city: map['city'] as String?,
      birthDate: parsedBirthDate,
    );
  }

  ProfileModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    int? ecoPoints,
    String? cedula,
    String? city,
    DateTime? birthDate,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      cedula: cedula ?? this.cedula,
      city: city ?? this.city,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  String get formattedEcoPoints =>
      NumberFormat('#,##0', 'en_US').format(ecoPoints);

  String get formattedBirthDate {
    if (birthDate == null) return '';
    return DateFormat('dd/MM/yyyy').format(birthDate!);
  }
}
