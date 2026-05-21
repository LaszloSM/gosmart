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
import '../../services/public_transport_service.dart';
import '../../providers/selected_mode_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/favorite_place.dart';
import '../../models/route_result.dart';
import '../../services/eco_service.dart';

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
    // Pre-fill destination si el usuario llegó via long-press en el mapa
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingDestination());
  }

  void _applyPendingDestination() {
    final pending = ref.read(pendingDestinationProvider);
    if (pending == null) return;
    _destCtrl.removeListener(_onDestChanged);
    _destCtrl.text =
        '${pending.latitude.toStringAsFixed(5)}, ${pending.longitude.toStringAsFixed(5)}';
    setState(() => _destLatLng = pending);
    _destCtrl.addListener(_onDestChanged);
    ref.read(pendingDestinationProvider.notifier).state = null;
  }

  void _swap() {
    _destCtrl.removeListener(_onDestChanged);
    final tmpText = _originCtrl.text;
    final tmpLatLng = _originLatLng;
    _originCtrl.text = _destCtrl.text;
    _destCtrl.text = tmpText;
    setState(() {
      _originLatLng = _destLatLng;
      _destLatLng = tmpLatLng;
      _suggestions = [];
    });
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

    if (_destLatLng == null) {
      GSToast.showWithMessenger(messenger,
          message: 'Selecciona un destino de las sugerencias.');
      return;
    }
    final destLatLng = _destLatLng!;

    setState(() => _loading = true);
    final mode = ref.read(selectedModeProvider);
    RouteResult? result;

    if (isPublicTransport(mode)) {
      result = await publicTransportService.planRoute(
        origin: _originLatLng!,
        destination: destLatLng,
        mode: mode,
      );
    } else {
      final profile = routeProfileFor(mode);
      result = await directionsService.getRoute(
        origin: _originLatLng!,
        destination: destLatLng,
        profile: profile,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (result != null) {
      ref.read(activeRouteProvider.notifier).state = result;

      // Sumar eco-puntos por rutas sostenibles (caminata o bici)
      const ecoProfiles = {'walking', 'cycling'};
      if (ecoProfiles.contains(result.profile)) {
        final pts = EcoService.ecoPointsForTrip(
          profile: result.profile,
          distanceKm: result.distanceKm,
        );
        if (pts > 0) {
          ref.read(profileProvider.notifier).addEcoPoints(pts);
          final co2 = EcoService.co2SavedGrams(
            profile: result.profile,
            distanceKm: result.distanceKm,
          );
          GSToast.showWithMessenger(
            messenger,
            message: '+$pts pts ecológicos — ${EcoService.formatCo2Saved(co2)} CO₂ ahorrado',
            type: GSToastType.success,
          );
        }
      }

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
    final currentMode = ref.watch(selectedModeProvider);
    final modeLabel = isPublicTransport(currentMode)
        ? 'Publico: $currentMode'
        : 'Privado: $currentMode';

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
          _LocationInputs(
            originCtrl: _originCtrl,
            destCtrl: _destCtrl,
            onSwap: _swap,
            destSuffixIcon: _destCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close,
                        color: GSColors.textDisabled, size: 18),
                    onPressed: () {
                      _destCtrl.removeListener(_onDestChanged);
                      _destCtrl.clear();
                      _destCtrl.addListener(_onDestChanged);
                      setState(() {
                        _destLatLng = null;
                        _suggestions = [];
                      });
                    },
                  )
                : null,
          ),
          // Autocomplete suggestions + favoritos rápidos
          Builder(builder: (context) {
            final home = ref.watch(homePlaceProvider);
            final work = ref.watch(workPlaceProvider);
            final showFavorites =
                _destCtrl.text.length < 2 && (home != null || work != null);
            final showSuggestions = _suggestions.isNotEmpty;
            if (!showFavorites && !showSuggestions) return const SizedBox();

            // Helper para construir un tile de favorito
            Widget favTile(FavoritePlace place, {bool divider = false}) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: GSSpacing.s3, vertical: GSSpacing.s1),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: place.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(GSRadius.sm),
                      ),
                      child: Icon(place.iconData, color: place.color, size: 18),
                    ),
                    title: Text(
                      place.typeLabel,
                      style: const TextStyle(
                          fontSize: 14,
                          color: GSColors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      place.address,
                      style: const TextStyle(
                          fontSize: 12, color: GSColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      _destCtrl.removeListener(_onDestChanged);
                      _destCtrl.text = place.name;
                      _destCtrl.addListener(_onDestChanged);
                      setState(() {
                        _destLatLng = place.latLng;
                        _suggestions = [];
                      });
                    },
                  ),
                  if (divider) const Divider(height: 1, color: GSColors.border),
                ],
              );
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(
                  GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.md),
                border: Border.all(color: GSColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Favoritos (casa / trabajo) ──────────────────────────
                  if (showFavorites) ...[
                    if (home != null)
                      favTile(home,
                          divider: work != null || showSuggestions),
                    if (work != null)
                      favTile(work, divider: showSuggestions),
                  ],
                  // ── Sugerencias de geocoding ────────────────────────────
                  if (showSuggestions)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: GSColors.border),
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: GSSpacing.s3,
                              vertical: GSSpacing.s1),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: GSColors.surfaceContainerLow,
                              borderRadius:
                                  BorderRadius.circular(GSRadius.sm),
                            ),
                            child: Icon(s.icon,
                                color: GSColors.textSecondary, size: 18),
                          ),
                          title: Text(
                            s.placeName,
                            style: const TextStyle(
                                fontSize: 14,
                                color: GSColors.textPrimary,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            s.fullAddress,
                            style: const TextStyle(
                                fontSize: 12,
                                color: GSColors.textDisabled),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                ],
              ),
            );
          }),
          // Mode indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    modeIconFor(currentMode),
                    size: 16,
                    color: GSColors.accent,
                  ),
                  const SizedBox(width: GSSpacing.s2),
                  Text(
                    modeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: GSColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
    required this.onSwap,
    this.destSuffixIcon,
  });
  final TextEditingController originCtrl;
  final TextEditingController destCtrl;
  final VoidCallback onSwap;
  final Widget? destSuffixIcon;

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
                GSTextField(
                  hint: 'Destino',
                  controller: destCtrl,
                  suffixIcon: destSuffixIcon,
                ),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded,
                color: GSColors.textSecondary),
            onPressed: onSwap,
          ),
        ],
      ),
    );
  }
}
