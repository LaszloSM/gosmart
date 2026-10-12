// lib/features/routes/route_planner_screen.dart
// Planificador: la placa de ruta se "pinta" mientras eliges desde, hasta y en
// qué vas. Origen y destino desde cualquier punto (dirección, referencia o
// punto del mapa por pulsación larga en el inicio).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/geocode_suggestion.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../services/directions_service.dart';
import '../../services/eco_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../services/public_transport_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_route_plate.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import 'widgets/mode_selector.dart';

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  LatLng? _originLatLng;
  LatLng? _destLatLng;
  List<GeocodeSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _resolveOrigin();
    _destCtrl.addListener(_onDestChanged);
    // Destino elegido con pulsación larga en el mapa del inicio.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _applyPendingDestination());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destCtrl.removeListener(_onDestChanged);
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _setDest(String text, LatLng? latLng) {
    _destCtrl.removeListener(_onDestChanged);
    _destCtrl.text = text;
    _destCtrl.addListener(_onDestChanged);
    setState(() {
      _destLatLng = latLng;
      _suggestions = [];
    });
  }

  void _applyPendingDestination() {
    final pending = ref.read(pendingDestinationProvider);
    if (pending == null) return;
    _setDest('Punto en el mapa', pending);
    ref.read(pendingDestinationProvider.notifier).state = null;
  }

  void _swap() {
    final text = _originCtrl.text;
    final latLng = _originLatLng;
    _originCtrl.text = _destCtrl.text;
    _originLatLng = _destLatLng;
    _setDest(text, latLng);
  }

  Future<void> _resolveOrigin() async {
    final pos = await locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _originLatLng = pos;
        _originCtrl.text = 'Mi ubicación';
      }
    });
  }

  void _onDestChanged() {
    final text = _destCtrl.text.trim();
    // Al editar a mano se pierde el punto elegido antes.
    if (_destLatLng != null) setState(() => _destLatLng = null);
    _debounce?.cancel();
    if (text.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results =
          await geocodingService.search(text, proximity: _originLatLng);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _search() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_originLatLng == null) {
      GSToast.showWithMessenger(messenger,
          message: _locating
              ? 'Estamos buscando tu ubicación. Espera un momento.'
              : 'No tenemos tu ubicación. Activa el GPS e intenta de nuevo.');
      return;
    }
    if (_destLatLng == null) {
      GSToast.showWithMessenger(messenger,
          message: 'Elige el destino de la lista de sugerencias.');
      return;
    }

    setState(() => _loading = true);
    final mode = ref.read(selectedModeProvider);
    final RouteResult? result = isPublicTransport(mode)
        ? await publicTransportService.planRoute(
            origin: _originLatLng!, destination: _destLatLng!, mode: mode)
        : await directionsService.getRoute(
            origin: _originLatLng!,
            destination: _destLatLng!,
            profile: routeProfileFor(mode));
    if (!mounted) return;
    setState(() => _loading = false);

    if (result == null) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos calcular la ruta. Revisa tu conexión.',
          type: GSToastType.error);
      return;
    }
    ref.read(activeRouteProvider.notifier).state = result;
    _awardEcoPoints(result, messenger);
    context.pop();
  }

  void _awardEcoPoints(RouteResult result, ScaffoldMessengerState messenger) {
    if (result.profile != RouteProfile.walking) return;
    // Los eco-puntos se guardan en el perfil: solo con cuenta.
    if (ref.read(isGuestProvider)) return;
    final pts = EcoService.ecoPointsForTrip(
        profile: result.profile, distanceKm: result.distanceKm);
    if (pts <= 0) return;
    ref.read(profileProvider.notifier).addEcoPoints(pts);
    GSToast.showWithMessenger(messenger,
        message: '+$pts eco-puntos por ir a pie', type: GSToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(selectedModeProvider);
    final home = ref.watch(homePlaceProvider);
    final work = ref.watch(workPlaceProvider);
    final showFavorites =
        _destCtrl.text.trim().length < 3 && (home != null || work != null);

    final originLabel = _originCtrl.text.isEmpty
        ? (_locating ? 'Buscando…' : 'Desde')
        : _originCtrl.text;
    final destChosen = _destLatLng != null;

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(
        title: const Text('¿A dónde vas?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Preguntarle al asistente',
            onPressed: () => context.push(AppRoutes.aiChat),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSSpacing.s6),
        children: [
          // La placa de ruta, pintada con lo que se va eligiendo.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
            child: GSRoutePlate(
              from: destChosen ? originLabel : null,
              text: destChosen ? _destCtrl.text : '¿Hasta dónde?',
              isPlaceholder: !destChosen,
              isActive: destChosen,
              detail: destChosen ? 'En $mode' : 'Desde $originLabel · en $mode',
              leading: modeIconFor(mode),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GSSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      GSTextField(
                        label: 'Desde',
                        hint: 'Tu ubicación',
                        controller: _originCtrl,
                        prefixIcon: Icons.my_location_rounded,
                      ),
                      const SizedBox(height: GSSpacing.s3),
                      GSTextField(
                        label: 'Hasta',
                        hint: 'Dirección o sitio',
                        controller: _destCtrl,
                        prefixIcon: Icons.place_outlined,
                        autofocus: _destCtrl.text.isEmpty,
                        suffixIcon: _destCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar destino',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => _setDest('', null),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GSSpacing.s2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 34),
                  child: IconButton(
                    tooltip: 'Intercambiar desde y hasta',
                    icon: const Icon(Icons.swap_vert_rounded,
                        color: GSColors.brand),
                    onPressed: _swap,
                  ),
                ),
              ],
            ),
          ),
          if (showFavorites) ...[
            if (home != null)
              GSListRow(
                icon: home.iconData,
                title: home.typeLabel,
                subtitle: home.address,
                onTap: () => _setDest(home.name, home.latLng),
              ),
            if (home != null && work != null)
              const Divider(indent: GSSpacing.s4),
            if (work != null)
              GSListRow(
                icon: work.iconData,
                title: work.typeLabel,
                subtitle: work.address,
                onTap: () => _setDest(work.name, work.latLng),
              ),
          ],
          for (var i = 0; i < _suggestions.length; i++) ...[
            if (i > 0) const Divider(indent: GSSpacing.s4),
            GSListRow(
              icon: _suggestions[i].icon,
              iconColor: GSColors.textMuted,
              title: _suggestions[i].placeName,
              subtitle: _suggestions[i].fullAddress,
              onTap: () => _setDest(
                  _suggestions[i].placeName, _suggestions[i].latLng),
            ),
          ],
          const GSSectionTitle('¿En qué vas?'),
          const SizedBox(height: GSSpacing.s2),
          ModeSelector(
            selected: mode,
            onChanged: (m) =>
                ref.read(selectedModeProvider.notifier).state = m,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s2,
              GSSpacing.s4, GSSpacing.s3 + MediaQuery.of(context).viewInsets.bottom),
          child: GSButton(
            label: 'Ver ruta',
            leadingIcon: Icons.route_rounded,
            isLoading: _loading,
            onPressed: _loading ? null : _search,
          ),
        ),
      ),
    );
  }
}
