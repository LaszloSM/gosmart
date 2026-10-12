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
import '../../services/eco_service.dart';
import '../../services/place_search.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import 'widgets/destination_plate.dart';
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
  String? _searchedFor;        // última búsqueda terminada
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

  void _applyPendingDestination() {
    final pending = ref.read(pendingDestinationProvider);
    if (pending == null) return;
    _setDest('Punto en el mapa', pending);
    ref.read(pendingDestinationProvider.notifier).state = null;
  }

  void _swap() {
    if (_destLatLng == null || _originLatLng == null) return;
    final label = _originLabel;
    final latLng = _originLatLng;
    setState(() {
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
      if (pos != null) _originLatLng = pos;
    });
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
    _debounce = Timer(const Duration(milliseconds: 300), () async {
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
    ref.read(activeRouteProvider.notifier).state =
        result.withDestination(_destLabel);
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
        : (_locating ? 'Buscando tu ubicación…' : 'Sin ubicación: activa el GPS');

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(
        title: const Text('Planear ruta'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Desde: tu ubicación (o el destino anterior tras intercambiar).
                Row(
                  children: [
                    Icon(Icons.my_location_rounded,
                        color: GSColors.textMuted),
                    const SizedBox(width: GSSpacing.s3),
                    Expanded(
                      child: Text(
                        'Desde: $originText',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Intercambiar origen y destino',
                      onPressed: _destLatLng != null && _originLatLng != null
                          ? _swap
                          : null,
                      icon: const Icon(Icons.swap_vert_rounded),
                      color: GSColors.brand,
                    ),
                  ],
                ),
                const SizedBox(height: GSSpacing.s2),
                DestinationPlate(
                  controller: _destCtrl,
                  chosenLabel: _destLabel,
                  autofocus: _destLabel == null,
                  onClear: () => _setDest('', null),
                ),
              ],
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
                onTap: () => _setDest(
                    _suggestions[i].placeName, _suggestions[i].latLng),
              ),
            ],
          if (typing && _searchedFor != null &&
              (_suggestions.isEmpty || _searchLimited))
            _SearchNotice(
              empty: _suggestions.isEmpty,
              limited: _searchLimited,
              query: _searchedFor!,
            ),
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
              GSSpacing.s4,
              GSSpacing.s3 + MediaQuery.of(context).viewInsets.bottom),
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
          Icon(limited ? Icons.cloud_off_outlined : Icons.search_off_rounded,
              size: 20, color: GSColors.textMuted),
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
