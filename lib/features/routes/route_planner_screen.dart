import 'dart:async';
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
import '../../models/geocode_suggestion.dart';
import '../../providers/active_route_provider.dart';
import '../../services/location_service.dart';
import '../../services/directions_service.dart';
import '../../services/geocoding_service.dart';
import '../../providers/selected_mode_provider.dart';

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();

  LatLng? _originLatLng;
  LatLng? _destLatLng;
  List<GeocodeSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolveOrigin();
    _destCtrl.addListener(_onDestChanged);
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

  void _onDestChanged() {
    final text = _destCtrl.text.trim();
    // Clear stored LatLng whenever user edits the field manually
    if (_destLatLng != null) {
      setState(() => _destLatLng = null);
    }
    if (text.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await geocodingService.search(
          text, proximity: _originLatLng);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _search() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_originLatLng == null) {
      GSToast.showWithMessenger(messenger,
          message: 'Obteniendo ubicación, espera un momento...');
      return;
    }

    LatLng? destLatLng = _destLatLng;
    if (destLatLng == null) {
      final suggestion = await geocodingService.geocodeFirst(
          _destCtrl.text.trim(), proximity: _originLatLng);
      if (!mounted) return;
      if (suggestion == null) {
        GSToast.showWithMessenger(messenger,
            message: 'Destino no encontrado. Selecciona una sugerencia.');
        return;
      }
      destLatLng = suggestion.latLng;
      setState(() => _destLatLng = destLatLng);
    }

    setState(() => _loading = true);
    final profile = routeProfileFor(ref.read(selectedModeProvider));
    final result = await directionsService.getRoute(
        origin: _originLatLng!, destination: destLatLng, profile: profile);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result != null) {
      ref.read(activeRouteProvider.notifier).state = result;
      context.pop();
    } else {
      GSToast.showWithMessenger(messenger,
          message: 'No se pudo calcular la ruta.');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destCtrl.removeListener(_onDestChanged);
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
          // Autocomplete suggestions
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(
                  GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.md),
                border: Border.all(color: GSColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: GSColors.border),
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined,
                        size: 18, color: GSColors.accent),
                    title: Text(s.placeName,
                        style: const TextStyle(
                            fontSize: 14,
                            color: GSColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(s.fullAddress,
                        style: const TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                    onTap: () {
                      _destCtrl.removeListener(_onDestChanged);
                      _destCtrl.text = s.placeName;
                      _destCtrl.addListener(_onDestChanged);
                      setState(() {
                        _destLatLng = s.latLng;
                        _suggestions = [];
                      });
                    },
                  );
                },
              ),
            ),
          // Mode indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
            child: Row(
              children: [
                Icon(
                  modeIconFor(ref.watch(selectedModeProvider)),
                  size: 16,
                  color: GSColors.accent,
                ),
                const SizedBox(width: GSSpacing.s2),
                Text(
                  'Modo: ${ref.watch(selectedModeProvider)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: GSColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s5),
            child: GSButton(
              label: _loading ? 'Buscando...' : 'Buscar ruta',
              onPressed: _loading ? null : _search,
              leadingIcon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: GSSpacing.s4),
        ],
      ),
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
