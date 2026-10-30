// lib/features/routes/route_planner_screen.dart
// Planificador: la placa de ruta se "pinta" mientras eliges desde, hasta y en
// qué vas. Origen y destino desde cualquier punto (dirección, referencia o
// punto del mapa por pulsación larga en el inicio).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/corridor_status.dart';
import '../../planner/fares.dart';
import '../../planner/graph.dart';
import '../../planner/planner.dart';
import '../../planner/to_route.dart';
import '../../providers/corridor_provider.dart';
import '../../providers/planner_provider.dart';
import '../../services/graph_service.dart';
import '../../models/geocode_suggestion.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../services/directions_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/eco_service.dart';
import '../../services/place_search.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import 'place_confirm_screen.dart';
import 'widgets/destination_plate.dart';
import 'widgets/mode_options.dart';
import 'widgets/mode_selector.dart';

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _destCtrl = TextEditingController();

  String _originLabel = 'Mi ubicación';
  LatLng? _originLatLng;
  LatLng? _destLatLng;
  String? _destLabel; // destino elegido (placa pintada)
  List<GeocodeSuggestion> _suggestions = [];
  bool _searchLimited = false; // el proveedor externo no respondió (D8)
  String? _searchedFor; // última búsqueda terminada
  Timer? _debounce;
  bool _loading = false;
  bool _locating = true;

  /// Origen puesto a mano ("Repetir" o intercambiar): el GPS ya no lo cambia.
  bool _originFixed = false;

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
    _destCtrl.dispose();
    super.dispose();
  }

  /// Elegir destino (placa pintada) o, con latLng null, volver a escribir.
  void _setDest(String text, LatLng? latLng) {
    _destCtrl.removeListener(_onDestChanged);
    _destCtrl.text = latLng == null ? '' : text;
    _destCtrl.addListener(_onDestChanged);
    setState(() {
      _destLatLng = latLng;
      _destLabel = latLng == null ? null : text;
      _suggestions = [];
    });
  }

  /// Todas pasan por `resolve` (Google trae el punto, también para los
  /// lugares del directorio sin verificar) y luego se confirman en el mapa.
  Future<void> _pickSuggestion(GeocodeSuggestion s) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    final place = await placeSearch.resolve(s);
    if (!mounted) return;
    setState(() => _loading = false);
    if (place?.latLng == null) {
      GSToast.showWithMessenger(messenger,
          message:
              'No pudimos ubicar ese lugar. Revisa tu conexión o elige otro.',
          type: GSToastType.error);
      return;
    }
    final confirmed = await context.push<GeocodeSuggestion>(
        AppRoutes.placeConfirm,
        extra: PlaceConfirmRequest(place!));
    // Volvió sin confirmar: la lista sigue ahí para elegir otro.
    if (confirmed == null || !mounted) return;
    _setDest(confirmed.placeName, confirmed.latLng);
  }

  void _applyPendingDestination() {
    // "Repetir" del historial: mismo origen y destino exactos.
    final plan = ref.read(pendingPlanProvider);
    if (plan != null) {
      ref.read(pendingPlanProvider.notifier).state = null;
      setState(() {
        _originFixed = true;
        _originLatLng = plan.origin;
        _originLabel = plan.originLabel;
      });
      _setDest(plan.destLabel, plan.dest);
      return;
    }
    final pending = ref.read(pendingDestinationProvider);
    if (pending == null) return;
    _setDest('Punto en el mapa', pending);
    ref.read(pendingDestinationProvider.notifier).state = null;
    // La dirección real del punto, cuando llegue.
    geocodingService.reverse(pending).then((a) {
      if (a != null && mounted && _destLatLng == pending) _setDest(a, pending);
    });
  }

  void _swap() {
    if (_destLatLng == null || _originLatLng == null) return;
    final label = _originLabel;
    final latLng = _originLatLng;
    setState(() {
      _originFixed = true;
      _originLabel = _destLabel!;
      _originLatLng = _destLatLng;
    });
    _setDest(label, latLng);
  }

  Future<void> _resolveOrigin() async {
    final pos = await locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null && !_originFixed) _originLatLng = pos;
    });
    if (pos == null || _originFixed) return;
    // "Mi ubicación" → la calle donde estás (como Uber).
    final address = await geocodingService.reverse(pos);
    if (address != null && mounted && _originLatLng == pos && _originLabel == 'Mi ubicación') {
      setState(() => _originLabel = address);
    }
  }

  void _onDestChanged() {
    final text = _destCtrl.text.trim();
    setState(() {}); // botón de borrar en el campo
    _debounce?.cancel();
    if (text.length < 3) {
      setState(() {
        _suggestions = [];
        _searchedFor = null;
      });
      return;
    }
    // 450 ms: se busca al hacer una pausa, no en cada letra (cada búsqueda
    // gasta cuota diaria de Google Places).
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final result = await placeSearch.search(text, near: _originLatLng);
      // Si el usuario siguió escribiendo, esta respuesta ya no aplica.
      if (!mounted || _destCtrl.text.trim() != text) return;
      setState(() {
        _suggestions = result.items;
        _searchLimited = result.limited;
        _searchedFor = text;
      });
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
        ? await _planWithGraph(mode)
        : await directionsService.getRoute(
            origin: _originLatLng!,
            destination: _destLatLng!,
            profile: routeProfileFor(mode));
    if (!mounted) return;
    setState(() => _loading = false);

    if (result == null) {
      GSToast.showWithMessenger(messenger,
          message: isPublicTransport(mode)
              ? 'Aún no tenemos $mode para ese viaje. Prueba en mototaxi o taxi.'
              : 'No pudimos calcular la ruta. Revisa tu conexión.',
          type: GSToastType.error);
      return;
    }
    // Mototaxi y taxi: precio único por la distancia real de la vía.
    var priced = result;
    final transit = TransitMode.fromName(mode.toLowerCase());
    if (transit == TransitMode.mototaxi || transit == TransitMode.taxi) {
      final rules = ref.read(transportGraphProvider).valueOrNull?.fareRules ??
          defaultFareRules;
      final fare = estimateFare(transit!, result.distanceKm,
          at: DateTime.now(), rules: rules);
      priced = result.withFare(
          fare.price, transit == TransitMode.taxi ? 'oficial' : 'sugerida');
    }
    ref.read(activeRouteProvider.notifier).state =
        priced.withDestination(_destLabel);
    _awardEcoPoints(result, messenger);
    context.pop();
  }

  /// Colectivo, TransPadilla e intermunicipal: planificador en el celular
  /// sobre el grafo guardado (D6), evitando tramos cerrados de la Troncal.
  Future<RouteResult?> _planWithGraph(String mode) async {
    final GraphBundle bundle;
    try {
      bundle = await ref.read(transportGraphProvider.future);
    } catch (_) {
      return null;
    }
    if (bundle.graph.isEmpty) return null;
    final corridor = ref.read(corridorStatusProvider).valueOrNull;
    final selected = TransitMode.values.firstWhere((m) => m.label == mode,
        orElse: () => TransitMode.colectivo);
    final trips = TripPlanner(bundle.graph, fareRules: bundle.fareRules).plan(
      PlanRequest(
        origin: _originLatLng!,
        destination: _destLatLng!,
        at: DateTime.now(),
        // El modo elegido más lo que se necesita para llegar y salir.
        allowed: {TransitMode.walk, TransitMode.mototaxi, selected},
        roadStates: {
          for (final s in corridor?.segments ?? const <CorridorSegment>[])
            if (s.id != null) s.id!: s.state,
        },
        originName: _originLabel,
        destinationName: _destLabel ?? 'Tu destino',
      ),
    );
    if (trips.isEmpty) return null;
    return routeFromTrip(trips.first, corridor: corridor);
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
    final typing = _destLabel == null;
    final showFavorites = typing &&
        _destCtrl.text.trim().length < 3 &&
        (home != null || work != null);
    final originText = _originLatLng != null
        ? _originLabel
        : (_locating
            ? 'Buscando tu ubicación…'
            : 'Sin ubicación: activa el GPS');

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(
        title: const Text('Planea tu viaje'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSSpacing.s6),
        children: [
          // Origen y destino en una tarjeta, unidos por una línea punteada
          // (como Uber): punto = desde, cuadro = hasta.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s3, GSSpacing.s2, GSSpacing.s3),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: GSColors.brand, width: 3),
                          ),
                        ),
                        for (var i = 0; i < 6; i++)
                          Container(
                            width: 2,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: GSColors.line,
                          ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: GSColors.text,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Desde',
                            style: Theme.of(context).textTheme.labelSmall),
                        Text(
                          originText,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: GSSpacing.s3),
                        DestinationPlate(
                          controller: _destCtrl,
                          chosenLabel: _destLabel,
                          autofocus: _destLabel == null,
                          onClear: () => _setDest('', null),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Intercambiar origen y destino',
                    onPressed: _destLatLng != null && _originLatLng != null
                        ? _swap
                        : null,
                    icon: const Icon(Icons.swap_vert_rounded),
                    color: GSColors.text,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: GSSpacing.s2),
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
          if (typing)
            for (var i = 0; i < _suggestions.length; i++) ...[
              if (i > 0) const Divider(indent: GSSpacing.s4),
              GSListRow(
                icon: _suggestions[i].icon,
                iconColor: GSColors.textMuted,
                title: _suggestions[i].placeName,
                subtitle: _suggestions[i].fullAddress,
                onTap: () => _pickSuggestion(_suggestions[i]),
              ),
            ],
          if (typing &&
              _searchedFor != null &&
              (_suggestions.isEmpty || _searchLimited))
            _SearchNotice(
              empty: _suggestions.isEmpty,
              limited: _searchLimited,
              query: _searchedFor!,
            ),
          // Sin destino todavía: accesos que siempre sirven (Google Maps).
          if (typing && _destCtrl.text.trim().length < 3) ...[
            const SizedBox(height: GSSpacing.s3),
            GSGroup(children: [
              GSListRow(
                icon: Icons.pin_drop_rounded,
                title: 'Elegir en el mapa',
                subtitle: 'Te llevamos al mapa: mantén presionado tu destino',
                onTap: () {
                  GSToast.show(context,
                      message: 'Mantén presionado el mapa en tu destino.');
                  context.go(AppRoutes.home);
                },
              ),
              GSListRow(
                icon: Icons.auto_awesome_rounded,
                title: 'Pregúntale al asistente',
                subtitle: '"¿Cómo llego al terminal de Maicao?"',
                onTap: () => context.push(AppRoutes.aiChat),
              ),
            ]),
          ],
          if (_destLatLng != null && _originLatLng != null) ...[
            const GSSectionTitle('Elige cómo ir'),
            ModeOptions(
              from: _originLatLng!,
              to: _destLatLng!,
              selected: mode,
              onChanged: (m) =>
                  ref.read(selectedModeProvider.notifier).state = m,
            ),
          ] else ...[
            const GSSectionTitle('¿En qué vas?'),
            ModeSelector(
              selected: mode,
              onChanged: (m) =>
                  ref.read(selectedModeProvider.notifier).state = m,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s2, GSSpacing.s4,
              GSSpacing.s3 + MediaQuery.of(context).viewInsets.bottom),
          child: GSButton(
            label: 'Ver ruta',
            leadingIcon: Icons.near_me_rounded,
            isLoading: _loading,
            onPressed: _loading ? null : _search,
          ),
        ),
      ),
    );
  }
}

/// Cuando no hay resultados o el buscador externo no respondió (D8): decirlo
/// y dar la salida que siempre funciona, marcar el punto en el mapa.
class _SearchNotice extends StatelessWidget {
  const _SearchNotice({
    required this.empty,
    required this.limited,
    required this.query,
  });
  final bool empty;
  final bool limited;
  final String query;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = empty ? 'No encontramos "$query"' : null;
    final body = limited
        ? 'Ahora solo buscamos en los lugares conocidos de la región. '
            'Si no aparece, mantén presionado el mapa del inicio en el punto.'
        : 'Prueba con una referencia cercana ("frente al parque") o mantén '
            'presionado el mapa del inicio en el punto.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, GSSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(limited ? Icons.cloud_off_rounded : Icons.search_off_rounded,
              size: GSSize.iconMd, color: GSColors.textMuted),
          const SizedBox(width: GSSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title, style: text.titleSmall),
                Text(body, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
