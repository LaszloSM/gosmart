import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../router/app_router.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../services/location_service.dart';
import '../../services/directions_service.dart';

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();

  LatLng? _originLatLng;
  List<RouteResult?> _results = [null, null, null]; // walking, driving, cycling
  bool _loading = false;
  String _selected = RouteProfile.walking;

  @override
  void initState() {
    super.initState();
    _resolveOrigin();
  }

  Future<void> _resolveOrigin() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _originLatLng = pos;
        _originCtrl.text = 'Mi ubicación';
      });
    }
  }

  /// Parses a "lat,lng" string. Returns null if invalid.
  LatLng? _parseDestination(String text) {
    final parts = text.trim().split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _search() async {
    if (_originLatLng == null) {
      final messenger = ScaffoldMessenger.of(context);
      GSToast.showWithMessenger(messenger,
          message: 'Obteniendo ubicación, espera un momento...');
      return;
    }

    final destLatLng = _parseDestination(_destCtrl.text);
    if (destLatLng == null) {
      final messenger = ScaffoldMessenger.of(context);
      GSToast.showWithMessenger(messenger,
          message: 'Formato inválido. Usa: lat,lng  (ej: 4.6097,-74.0817)');
      return;
    }

    setState(() => _loading = true);

    final results = await Future.wait([
      directionsService.getRoute(
          origin: _originLatLng!, destination: destLatLng, profile: RouteProfile.walking),
      directionsService.getRoute(
          origin: _originLatLng!, destination: destLatLng, profile: RouteProfile.driving),
      directionsService.getRoute(
          origin: _originLatLng!, destination: destLatLng, profile: RouteProfile.cycling),
    ]);

    if (mounted) setState(() { _results = results; _loading = false; });
  }

  void _selectRoute(String profile, int index) {
    setState(() => _selected = profile);
    final route = _results[index];
    if (route != null) {
      ref.read(activeRouteProvider.notifier).state = route;
      context.pop();
    }
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Planificar Ruta'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Preguntar IA',
            onPressed: () => context.push(AppRoutes.aiChat),
          ),
        ],
      ),
      body: Column(
        children: [
          _LocationInputs(originCtrl: _originCtrl, destCtrl: _destCtrl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s5),
            child: GSButton(
              label: _loading ? 'Buscando...' : 'Buscar ruta',
              onPressed: _loading ? null : _search,
              leadingIcon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: GSSpacing.s4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: GSSpacing.s5, vertical: GSSpacing.s2),
              children: [
                _buildCard(RouteProfile.walking, 0,
                    icon: Icons.directions_walk_rounded,
                    iconColor: GSColors.accent),
                const SizedBox(height: GSSpacing.s3),
                _buildCard(RouteProfile.driving, 1,
                    icon: Icons.directions_bus_rounded,
                    iconColor: const Color(0xFFFF8C00)),
                const SizedBox(height: GSSpacing.s3),
                _buildCard(RouteProfile.cycling, 2,
                    icon: Icons.pedal_bike_rounded,
                    iconColor: GSColors.eco),
                const SizedBox(height: GSSpacing.s6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String profile, int index,
      {required IconData icon, required Color iconColor}) {
    final result = _results[index];
    final timeStr = result != null ? '${result.durationMin} min' : '—';
    final distStr = result != null
        ? '${result.distanceKm.toStringAsFixed(1)} km'
        : '—';

    return _RouteCard(
      option: _RouteOption(
        id: profile,
        label: RouteProfile.labelFor(profile),
        icon: icon,
        iconColor: iconColor,
        time: timeStr,
        cost: distStr,
        co2: '',
        steps: const [],
      ),
      isSelected: _selected == profile,
      onTap: () => _selectRoute(profile, index),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location inputs
// ─────────────────────────────────────────────────────────────────────────────

class _LocationInputs extends StatelessWidget {
  const _LocationInputs({
    required this.originCtrl,
    required this.destCtrl,
  });
  final TextEditingController originCtrl;
  final TextEditingController destCtrl;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      margin: const EdgeInsets.all(GSSpacing.s5),
      padding: const EdgeInsets.all(GSSpacing.s4),
      shadow: GSShadow.md,
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: GSColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 36, color: GSColors.border),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: GSColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              children: [
                GSTextField(hint: 'Origen', controller: originCtrl),
                const SizedBox(height: GSSpacing.s3),
                GSTextField(hint: 'Destino', controller: destCtrl),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded,
                color: GSColors.textSecondary),
            onPressed: () {
              final tmp = originCtrl.text;
              originCtrl.text = destCtrl.text;
              destCtrl.text = tmp;
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route option data class
// ─────────────────────────────────────────────────────────────────────────────

class _RouteOption {
  final String id;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String time;
  final String cost;
  final String co2;
  final List<_Step> steps;

  const _RouteOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.cost,
    required this.co2,
    required this.steps,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Step data class
// ─────────────────────────────────────────────────────────────────────────────

class _Step {
  final String label;
  final IconData icon;
  final Color color;

  const _Step({
    required this.label,
    required this.icon,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Route card
// ─────────────────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });
  final _RouteOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GSDuration.normal,
        padding: const EdgeInsets.all(GSSpacing.s4),
        decoration: BoxDecoration(
          color: isSelected ? GSColors.accentLight : GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          border: Border.all(
            color: isSelected ? GSColors.accent : GSColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? GSShadow.primary : GSShadow.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icon + label + stats
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: option.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(GSRadius.sm),
                  ),
                  child: Icon(option.icon, color: option.iconColor, size: 20),
                ),
                const SizedBox(width: GSSpacing.s3),
                Expanded(
                  child: Text(
                    option.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: GSColors.textPrimary,
                    ),
                  ),
                ),
                _StatBadge(Icons.access_time_rounded, option.time),
                const SizedBox(width: GSSpacing.s2),
                _StatBadge(
                  Icons.straighten_rounded,
                  option.cost,
                  color: GSColors.eco,
                ),
              ],
            ),
            if (option.steps.isNotEmpty) ...[
              const SizedBox(height: GSSpacing.s4),
              // Timeline
              Row(
                children: option.steps.map((s) {
                  final isLast = s == option.steps.last;
                  return Expanded(
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: s.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(s.icon, size: 16, color: s.color),
                            ),
                            const SizedBox(height: 4),
                            Text(s.label,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: GSColors.textPrimary)),
                          ],
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.only(bottom: 16),
                              color: GSColors.border,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (option.co2.isNotEmpty) ...[
              const SizedBox(height: GSSpacing.s3),
              Row(
                children: [
                  const Icon(Icons.eco_rounded, size: 14, color: GSColors.eco),
                  const SizedBox(width: 4),
                  Text(
                    option.co2,
                    style: const TextStyle(
                        fontSize: 12,
                        color: GSColors.eco,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge(this.icon, this.label, {this.color = GSColors.accent});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
