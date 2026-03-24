// lib/features/onboarding/location_permission_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends State<LocationPermissionScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GSSpacing.s6),
          child: Column(
            children: [
              const Spacer(),
              // Ilustración
              _buildIllustration(),
              const SizedBox(height: GSSpacing.s8),
              // Título
              const Text(
                '¿Dónde estás?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GSColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GSSpacing.s4),
              const Text(
                'GoSmart necesita tu ubicación para mostrarte rutas '
                'personalizadas, estaciones cercanas y tiempos de llegada precisos.',
                style: TextStyle(
                  fontSize: 16,
                  color: GSColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GSSpacing.s6),
              // Beneficios
              _buildBenefit(
                Icons.near_me_rounded,
                'Rutas desde tu ubicación actual',
              ),
              _buildBenefit(
                Icons.access_time_rounded,
                'Tiempos de llegada en tiempo real',
              ),
              _buildBenefit(
                Icons.directions_bus_rounded,
                'Paradas y estaciones cercanas',
              ),
              // Error
              if (_error != null) ...[
                const SizedBox(height: GSSpacing.s4),
                Container(
                  padding: const EdgeInsets.all(GSSpacing.s3),
                  decoration: BoxDecoration(
                    color: GSColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(GSRadius.md),
                    border: Border.all(
                      color: GSColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: GSColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: GSSpacing.s2),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: GSColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Botón principal
              GSButton(
                label: 'Permitir ubicación',
                onPressed: _loading ? null : _requestPermission,
                isLoading: _loading,
              ),
              const SizedBox(height: GSSpacing.s3),
              // Botón secundario
              GSButton(
                label: 'Ahora no',
                variant: GSButtonVariant.ghost,
                onPressed: _loading ? null : _skip,
              ),
              const SizedBox(height: GSSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: GSColors.accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: GSColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          const Icon(
            Icons.location_on_rounded,
            size: 64,
            color: GSColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: GSColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(GSRadius.sm),
            ),
            child: Icon(icon, color: GSColors.accent, size: 16),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: GSColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error =
              'El GPS está desactivado. Actívalo en los ajustes del dispositivo.';
          _loading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _error = 'Permiso denegado. Puedes habilitarlo más tarde en Ajustes.';
          _loading = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error =
              'Permiso bloqueado. Ve a Ajustes → GoSmart → Permisos → Ubicación.';
          _loading = false;
        });
        await Geolocator.openAppSettings();
        return;
      }

      // Permiso concedido
      await _completeOnboarding();
    } catch (e) {
      setState(() {
        _error = 'Error al solicitar permiso: $e';
        _loading = false;
      });
    }
  }

  void _skip() => _completeOnboarding();

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.go('/onboarding');
  }
}
