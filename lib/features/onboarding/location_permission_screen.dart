// lib/features/onboarding/location_permission_screen.dart
// Pedir la ubicación diciendo para qué sirve hoy, sin prometer lo que
// todavía no existe. Se puede seguir sin darla.
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_inline_error.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _loading = false;
  String? _error;
  bool _blocked = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(
        title: const Text('Tu ubicación'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(GSSpacing.s4),
          children: [
            Text('Para planear desde donde estás', style: text.titleLarge),
            const SizedBox(height: GSSpacing.s3),
            _Point(
              icon: Icons.near_me_outlined,
              text: 'La ruta empieza en tu punto, sin escribir la dirección.',
              style: text.bodyLarge,
            ),
            _Point(
              icon: Icons.map_outlined,
              text: 'El mapa abre en tu barrio de Riohacha o Maicao.',
              style: text.bodyLarge,
            ),
            _Point(
              icon: Icons.visibility_off_outlined,
              text: 'Solo se usa mientras tienes la app abierta. Si prefieres, '
                  'escribe la dirección cada vez.',
              style: text.bodyLarge,
            ),
            if (_error != null) ...[
              const SizedBox(height: GSSpacing.s4),
              GSInlineError(
                message: _error!,
                onRetry: _blocked
                    ? () => Geolocator.openAppSettings()
                    : _requestPermission,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GSButton(
                label: 'Usar mi ubicación',
                onPressed: _loading ? null : _requestPermission,
                isLoading: _loading,
              ),
              const SizedBox(height: GSSpacing.s2),
              GSButton(
                label: 'Ahora no',
                variant: GSButtonVariant.ghost,
                onPressed: _loading ? null : _completeOnboarding,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _loading = true;
      _error = null;
      _blocked = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _error = 'El GPS está apagado. Actívalo y vuelve a intentar.';
          _loading = false;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'La ubicación está bloqueada para GoSmart. Actívala en '
              'Ajustes del teléfono.';
          _blocked = true;
          _loading = false;
        });
        return;
      }
      if (permission == LocationPermission.denied) {
        // Decidió que no: se respeta y se sigue.
        await _completeOnboarding();
        return;
      }
      await _completeOnboarding();
    } catch (_) {
      setState(() {
        _error = 'No pudimos pedir el permiso. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.go(AppRoutes.home);
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text, this.style});
  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GSColors.brand, size: 26),
          const SizedBox(width: GSSpacing.s3),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
