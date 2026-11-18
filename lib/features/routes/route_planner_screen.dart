// lib/features/routes/route_planner_screen.dart
// Planificador estilo Uber/InDrive: recogida y destino en una tarjeta (los
// dos se pueden escribir: el GPS no siempre es exacto), las opciones con su
// precio y, para mototaxi y taxi, "Pedir" en un toque: crea el viaje y ya
// busca conductor (quick_ride, 026). Sin confirmar el pin cuando el lugar es
// exacto; solo los aproximados pasan por el mapa.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../core/region.dart';
import '../../models/corridor_status.dart';
import '../../planner/fares.dart';
import '../../planner/graph.dart';
import '../../planner/planner.dart';
import '../../planner/to_route.dart';
import '../../providers/corridor_provider.dart';
import '../../providers/dispatch_provider.dart';
import '../../services/dispatch_service.dart';
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
import '../../services/road_snap.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_pressable.dart';
import '../../widgets/gs_toast.dart';
import 'place_confirm_screen.dart';
import 'widgets/mode_options.dart';
import 'widgets/mode_selector.dart';

/// Viaje mínimo para pedir (150 m): menos es casi seguro un punto mal puesto.
const minTripKm = 0.15;

/// Qué punto se está escribiendo en el buscador.
enum _Field { origin, dest }

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  String _originLabel = 'Mi ubicación';
  LatLng? _originLatLng;
  LatLng? _destLatLng;
  String? _destLabel;

  /// Qué se está escribiendo; null = los dos puntos listos (se ven los modos).
  _Field? _editing = _Field.dest;

  List<GeocodeSuggestion> _suggestions = [];
  bool _searchLimited = false; // el proveedor externo no respondió (D8)
  String? _searchedFor; // última búsqueda terminada
  Timer? _debounce;
  bool _loading = false;
  bool _locating = true;

  /// El origen sigue al GPS mientras sea "mi ubicación" (no un punto elegido).
  bool _originIsMe = true;
  LocationIssue? _locationIssue;
  StreamSubscription<LatLng>? _positions;

  /// Ruta por la vía entre los dos puntos (para el precio de mototaxi/taxi);
  /// null mientras se calcula o si Google no respondió (se usa el estimado).
  RouteResult? _driveRoute;
  int _routeToken = 0;

  /// Llave del pedido: tocar dos veces "Pedir" no crea dos viajes. Cambia
  /// cuando cambia algo del pedido (puntos o modo).
  String _rideKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    // Si ya hay una posición (del mapa del inicio), se usa al instante y se
    // afina en segundo plano: no hay que esperar al GPS para planear.
    final known = locationService.last;
    if (known != null) {
      _originLatLng = known;
      _locating = false;
    }
    _positions = locationService.positions.listen((p) {
      if (!mounted || !_originIsMe) return;
      final first = _originLatLng == null;
      setState(() {
        _originLatLng = p;
        _locating = false;
        _locationIssue = null;
      });
      if (first) {
        _labelOrigin(p);
        _pointsChanged();
      }
    });
    _resolveOrigin();
    _query.addListener(_onQueryChanged);
    // Destino elegido con pulsación larga en el mapa del inicio, o "Pedir de
    // nuevo" desde el historial.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _applyPendingDestination());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _positions?.cancel();
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Puntos ──────────────────────────────────────────────────────────────
  void _setDest(String label, LatLng latLng) {
    setState(() {
      _destLatLng = latLng;
      _destLabel = label;
      // Si el origen aún no está, se pide; si no, listo para elegir modo.
      _editing = _originLatLng == null && !_originIsMe ? _Field.origin : null;
    });
    _clearQuery();
    _pointsChanged();
  }

  void _setOrigin(String label, LatLng latLng, {bool isMe = false}) {
    setState(() {
      _originIsMe = isMe;
      _originLatLng = latLng;
      _originLabel = label;
      _editing = _destLatLng == null ? _Field.dest : null;
    });
    _clearQuery();
    _pointsChanged();
  }

  /// Volver a escribir uno de los dos puntos (tocar su fila).
  void _edit(_Field f) {
    setState(() => _editing = f);
    _clearQuery();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _clearQuery() {
    _query.removeListener(_onQueryChanged);
    _query.clear();
    _query.addListener(_onQueryChanged);
    _debounce?.cancel();
    setState(() {
      _suggestions = [];
      _searchedFor = null;
    });
  }

  /// Cambió un punto: pedido nuevo y ruta por la vía para el precio.
  void _pointsChanged() {
    _rideKey = const Uuid().v4();
    final from = _originLatLng, to = _destLatLng;
    final token = ++_routeToken;
    setState(() => _driveRoute = null);
    if (from == null || to == null) return;
    directionsService
        .getRoute(origin: from, destination: to, profile: RouteProfile.driving)
        .then((r) {
      if (mounted && token == _routeToken) setState(() => _driveRoute = r);
    }).catchError((_) {});
  }

  /// Todas pasan por `resolve` (Google trae el punto). Si el punto es
  /// aproximado (lugar sin verificar sin respuesta de Google) se confirma en
  /// el mapa; si es exacto se usa directo: un paso menos.
  Future<void> _pickSuggestion(GeocodeSuggestion s) async {
    final messenger = ScaffoldMessenger.of(context);
    final field = _editing ?? _Field.dest;
    setState(() => _loading = true);
    final place = await placeSearch.resolve(s);
    if (!mounted) return;
    setState(() => _loading = false);
    if (place?.latLng == null) {
      GSToast.showWithMessenger(messenger,
          message: s.typedAddress
              ? 'No encontramos "${s.placeName}" en el mapa. Márcala tú.'
              : 'No pudimos ubicar ese lugar. Revisa tu conexión o elige otro.',
          type: GSToastType.warning,
          duration: const Duration(seconds: 6),
          actionLabel: 'Marcar en el mapa',
          onAction: () => _adjustOnMap(field));
      return;
    }
    var chosen = place!;
    if (chosen.approximate) {
      final confirmed = await _confirmOnMap(chosen, field);
      if (confirmed?.latLng == null || !mounted) return;
      // Una dirección escrita conserva su texto ("Calle 14 # 10-20"): es lo
      // que lee el conductor. Del mapa solo se toma el punto.
      chosen = chosen.typedAddress
          ? chosen.withLocation(confirmed!.latLng!)
          : confirmed!;
    }
    if (field == _Field.origin) {
      _setOrigin(chosen.placeName, chosen.latLng!);
    } else {
      _setDest(chosen.placeName, chosen.latLng!);
    }
  }

  Future<GeocodeSuggestion?> _confirmOnMap(GeocodeSuggestion place, _Field f) {
    FocusScope.of(context).unfocus();
    return context.push<GeocodeSuggestion>(AppRoutes.placeConfirm,
        extra: PlaceConfirmRequest(place,
            title: place.typedAddress
                ? 'Mueve el pin hasta la puerta'
                : f == _Field.origin
                    ? '¿Dónde te recogemos?'
                    : 'Confirma el destino',
            actionLabel: f == _Field.origin ? 'Recoger aquí' : 'Confirmar destino'));
  }

  /// Mover el pin a mano: más preciso que el GPS para que el conductor llegue.
  Future<void> _adjustOnMap(_Field f) async {
    final at = f == _Field.origin ? _originLatLng : _destLatLng;
    final start = at ?? locationService.last ?? GSRegion.riohacha;
    final label = f == _Field.origin
        ? (_originIsMe ? 'Tu ubicación' : _originLabel)
        : (_destLabel ?? 'Punto en el mapa');
    final confirmed = await _confirmOnMap(
        GeocodeSuggestion(placeName: label, fullAddress: '', latLng: start), f);
    if (confirmed?.latLng == null || !mounted) return;
    if (f == _Field.origin) {
      _setOrigin(confirmed!.placeName, confirmed.latLng!);
    } else {
      _setDest(confirmed!.placeName, confirmed.latLng!);
    }
  }

  void _useMyLocation() {
    final at = locationService.last ?? _originLatLng;
    _originIsMe = true;
    if (at != null) {
      _setOrigin('Mi ubicación', at, isMe: true);
      _labelOrigin(at);
    } else {
      setState(() => _editing = _destLatLng == null ? _Field.dest : null);
      _resolveOrigin();
    }
  }

  void _applyPendingDestination() {
    // "Pedir de nuevo" del historial: mismo origen y destino exactos.
    final plan = ref.read(pendingPlanProvider);
    if (plan != null) {
      ref.read(pendingPlanProvider.notifier).state = null;
      setState(() {
        _originIsMe = false;
        _originLatLng = plan.origin;
        _originLabel = plan.originLabel;
        _destLatLng = plan.dest;
        _destLabel = plan.destLabel;
        _editing = null;
      });
      _pointsChanged();
      return;
    }
    final named = ref.read(pendingNamedDestinationProvider);
    if (named != null) {
      ref.read(pendingNamedDestinationProvider.notifier).state = null;
      _setDest(named.label, named.at);
      return;
    }
    final pending = ref.read(pendingDestinationProvider);
    if (pending == null) return;
    ref.read(pendingDestinationProvider.notifier).state = null;
    _setDest('Punto en el mapa', pending);
    // La dirección real del punto, cuando llegue.
    geocodingService.reverse(pending).then((a) {
      if (a != null && mounted && _destLatLng == pending) {
        setState(() => _destLabel = a);
      }
    });
  }

  void _swap() {
    final from = _originLatLng, to = _destLatLng;
    if (from == null || to == null) return;
    final label = _originLabel;
    setState(() {
      _originIsMe = false;
      _originLabel = _destLabel!;
      _originLatLng = to;
      _destLabel = label;
      _destLatLng = from;
    });
    _pointsChanged();
  }

  Future<void> _resolveOrigin() async {
    setState(() {
      _locating = _originLatLng == null;
      _locationIssue = null;
    });
    final pos = await locationService.getCurrentPosition();
    if (!mounted) return;
    final firstFix = _originLatLng == null;
    setState(() {
      _locating = false;
      if (pos != null && _originIsMe) _originLatLng = pos;
      if (pos == null && _originLatLng == null) {
        _locationIssue = locationService.lastIssue ?? LocationIssue.noFix;
      }
    });
    if (pos != null && _originIsMe) {
      _labelOrigin(pos);
      if (firstFix) _pointsChanged();
    }
  }

  /// "Mi ubicación" → la calle donde estás (como Uber).
  Future<void> _labelOrigin(LatLng pos) async {
    final address = await geocodingService.reverse(pos);
    if (address != null && mounted && _originIsMe) {
      setState(() => _originLabel = address);
    }
  }

  /// Arreglar lo que impide ubicarte (GPS apagado, permiso) y reintentar.
  Future<void> _fixLocation() async {
    final issue = _locationIssue;
    if (issue != null) await locationService.fix(issue);
    if (mounted) await _resolveOrigin();
  }

  void _onQueryChanged() {
    final text = _query.text.trim();
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
    // gasta cuota diaria de Google Places). Cerca de la persona: su ciudad
    // primero (city_rank.dart).
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final near = locationService.last ?? _originLatLng;
      final result = await placeSearch.search(text, near: near);
      if (!mounted || _query.text.trim() != text) return;
      setState(() {
        _suggestions = result.items;
        _searchLimited = result.limited;
        _searchedFor = text;
      });
    });
  }

  // ── Precio y pedido ─────────────────────────────────────────────────────
  static bool _isRide(String mode) => mode == 'Mototaxi' || mode == 'Taxi';

  /// Tarifa y minutos con los que se pide: por la vía si Google respondió;
  /// si no, el estimado en línea recta × 1,3 (igual que la lista de modos).
  ({int fare, int minutes, double km})? _quote(String mode) {
    final from = _originLatLng, to = _destLatLng;
    final transit = TransitMode.fromName(mode.toLowerCase());
    if (from == null || to == null || transit == null) return null;
    final km = _driveRoute?.distanceKm ?? haversineKm(from, to) * 1.3;
    final rules = ref.read(transportGraphProvider).valueOrNull?.fareRules ??
        defaultFareRules;
    final fare = estimateFare(transit, km, at: DateTime.now(), rules: rules);
    if (fare.isZero) return null;
    final minutes = _driveRoute?.durationMin ??
        estimateMode(mode, from, to, DateTime.now()).minutes;
    // En múltiplos de $100, como se paga.
    final price = ((fare.price / 100).round() * 100).clamp(1000, 500000).toInt();
    return (fare: price, minutes: minutes, km: km);
  }

  /// Un toque: crea el viaje y empieza a buscar conductor en el servidor
  /// (quick_ride). La pantalla del viaje abre ya buscando, sin "oferta" ni
  /// "Iniciar viaje" de por medio.
  Future<void> _requestNow(String mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (ref.read(isGuestProvider)) {
      GSToast.showWithMessenger(messenger,
          message: 'Entra a tu cuenta para pedir el viaje.');
      router.push(AppRoutes.login);
      return;
    }
    final from = _originLatLng, to = _destLatLng;
    final q = _quote(mode);
    if (from == null || to == null || q == null) return;
    // Recogida y destino casi en el mismo punto: casi siempre es una
    // dirección mal ubicada. Mejor revisarla que pedir un viaje de la casa
    // a la casa.
    if (haversineKm(from, to) < minTripKm) {
      GSToast.showWithMessenger(messenger,
          message: 'El destino quedó casi en el mismo punto de recogida. '
              'Revisa la dirección del destino.',
          type: GSToastType.warning,
          duration: const Duration(seconds: 6),
          actionLabel: 'Ajustar',
          onAction: () => _adjustOnMap(_Field.dest));
      return;
    }
    final service = mode == 'Taxi' ? 'taxi' : 'mototaxi';
    final originLabel = _originIsMe && _originLabel == 'Mi ubicación'
        ? 'Tu ubicación'
        : _originLabel;
    setState(() => _loading = true);
    try {
      await dispatchService.quickRide(
        service: service,
        origin: from,
        originLabel: originLabel,
        dest: to,
        destLabel: _destLabel ?? 'Destino',
        fare: q.fare,
        minutes: q.minutes,
        idempotencyKey: _rideKey,
      );
      // El mapa del viaje dibuja la ruta por la vía si la tenemos.
      final route = _driveRoute;
      ref.read(activeRouteProvider.notifier).state = route
          ?.withFare(q.fare, service == 'taxi' ? 'oficial' : 'sugerida')
          .withDestination(_destLabel);
      ref.invalidate(activeTripProvider);
      router.go(AppRoutes.trip);
    } on DispatchException catch (e) {
      if (e.code == 'trip_in_progress') {
        GSToast.showWithMessenger(messenger,
            message: 'Ya tienes un viaje en curso. Te llevamos a él.');
        ref.invalidate(activeTripProvider);
        router.go(AppRoutes.trip);
      } else {
        GSToast.showWithMessenger(messenger,
            message: e.message, type: GSToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Colectivo, TransPadilla, intermunicipal, a pie y carro: ver la ruta.
  Future<void> _search() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_originLatLng == null) {
      if (_locating) {
        GSToast.showWithMessenger(messenger,
            message: 'Estamos buscando tu ubicación. Espera un momento.');
      } else {
        final issue = _locationIssue ?? LocationIssue.noFix;
        GSToast.showWithMessenger(messenger,
            message: locationIssueText(issue),
            type: GSToastType.warning,
            duration: const Duration(seconds: 6),
            actionLabel: issue == LocationIssue.noFix ? 'Reintentar' : 'Activar',
            onAction: _fixLocation);
      }
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
    // Cada tramo por la vía (no en línea recta) antes de pintarlo.
    return roadSnapper.snap(routeFromTrip(trips.first, corridor: corridor));
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

  // ── Pantalla ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(selectedModeProvider);
    final home = ref.watch(homePlaceProvider);
    final work = ref.watch(workPlaceProvider);
    final saved = ref.watch(customPlacesProvider);
    final editing = _editing;
    final typing = editing != null;
    final shortQuery = _query.text.trim().length < 3;
    final ready = _destLatLng != null && _originLatLng != null && !typing;
    final originText = _originLatLng != null
        ? _originLabel
        : (_locating
            ? 'Buscando tu ubicación…'
            : locationIssueText(_locationIssue ?? LocationIssue.noFix));

    void pickSaved(String name, LatLng at) {
      if (editing == _Field.origin) {
        _setOrigin(name, at);
      } else {
        _setDest(name, at);
      }
    }

    final showSaved = typing &&
        shortQuery &&
        (home != null || work != null || saved.isNotEmpty);
    // Recientes (como Uber): los últimos destinos, sin repetir.
    final recents = <({String label, LatLng at})>[];
    if (typing && shortQuery) {
      for (final h in ref.watch(recentPlacesProvider).valueOrNull ?? const []) {
        if (recents.length >= 3) break;
        if (recents.any((r) => r.label == h.label)) continue;
        if (h.label == home?.name || h.label == work?.name) continue;
        recents.add(h);
      }
    }

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('¿A dónde vas?')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSSpacing.s6),
        children: [
          // Recogida y destino en una tarjeta (Uber/InDrive): punto = recoger,
          // cuadro = destino. Cada fila se toca para cambiarla.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s3, GSSpacing.s2, GSSpacing.s1, GSSpacing.s2),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PointRow(
                          dot: _Dot.origin,
                          label: 'Recoger en',
                          value: originText,
                          editing: editing == _Field.origin,
                          controller: _query,
                          focusNode: _focus,
                          hint: '¿Dónde te recogemos?',
                          onTap: () => _edit(_Field.origin),
                          onClose: _destLatLng == null && _originLatLng == null
                              ? null
                              : () => setState(() =>
                                  _editing = _destLatLng == null ? _Field.dest : null),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Divider(height: 1, color: GSColors.line),
                        ),
                        _PointRow(
                          dot: _Dot.dest,
                          label: 'Destino',
                          value: _destLabel ?? '¿A dónde vas?',
                          placeholder: _destLabel == null,
                          editing: editing == _Field.dest,
                          controller: _query,
                          focusNode: _focus,
                          hint: 'Dirección, barrio o lugar',
                          autofocus: _destLabel == null,
                          onTap: () => _edit(_Field.dest),
                          onClose: _destLatLng == null
                              ? null
                              : () => setState(() => _editing = null),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Intercambiar recogida y destino',
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
          if (_originLatLng == null && !_locating && editing != _Field.origin)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, 0),
              child: Row(children: [
                TextButton.icon(
                  onPressed: _fixLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(switch (_locationIssue) {
                    LocationIssue.serviceOff => 'Activar GPS',
                    LocationIssue.denied => 'Dar permiso',
                    LocationIssue.deniedForever => 'Abrir ajustes',
                    _ => 'Reintentar',
                  }),
                ),
                TextButton(
                  onPressed: () => _edit(_Field.origin),
                  child: const Text('Escribir dirección'),
                ),
              ]),
            ),
          if (_loading && typing)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: GSSpacing.s2),

          // ── Escribiendo un punto ────────────────────────────────────────
          if (typing && shortQuery) ...[
            GSGroup(children: [
              if (editing == _Field.origin)
                GSListRow(
                  icon: Icons.my_location_rounded,
                  title: 'Usar mi ubicación actual',
                  subtitle: 'Por GPS. Si no es exacta, escribe la dirección',
                  onTap: _useMyLocation,
                ),
              GSListRow(
                icon: Icons.pin_drop_rounded,
                title: 'Elegir en el mapa',
                subtitle: editing == _Field.origin
                    ? 'Mueve el pin hasta la puerta donde esperas'
                    : 'Mueve el pin hasta tu destino',
                onTap: () => _adjustOnMap(editing),
              ),
            ]),
            const SizedBox(height: GSSpacing.s2),
          ],
          if (showSaved) ...[
            if (home != null)
              GSListRow(
                icon: home.iconData,
                title: home.typeLabel,
                subtitle: home.address,
                onTap: () => pickSaved(home.name, home.latLng),
              ),
            if (home != null && work != null)
              const Divider(indent: GSSpacing.s4),
            if (work != null)
              GSListRow(
                icon: work.iconData,
                title: work.typeLabel,
                subtitle: work.address,
                onTap: () => pickSaved(work.name, work.latLng),
              ),
            // Tus lugares con nombre ("Donde mi mamá", "Gimnasio").
            for (final p in saved) ...[
              if (home != null || work != null || p != saved.first)
                const Divider(indent: GSSpacing.s4),
              GSListRow(
                icon: Icons.bookmark_rounded,
                title: p.name,
                subtitle: p.address,
                onTap: () {
                  ref.read(favoritesNotifierProvider.notifier).incrementUseCount(p.id);
                  pickSaved(p.name, p.latLng);
                },
              ),
            ],
          ],
          if (recents.isNotEmpty) ...[
            const GSSectionTitle('Recientes'),
            for (var i = 0; i < recents.length; i++) ...[
              if (i > 0) const Divider(indent: GSSpacing.s4),
              GSListRow(
                icon: Icons.history_rounded,
                iconColor: GSColors.textMuted,
                title: recents[i].label,
                onTap: () => pickSaved(recents[i].label, recents[i].at),
              ),
            ],
          ],
          if (typing)
            for (var i = 0; i < _suggestions.length; i++) ...[
              if (i > 0) const Divider(indent: GSSpacing.s4),
              GSListRow(
                icon: _suggestions[i].icon,
                iconColor: GSColors.textMuted,
                title: _suggestions[i].placeName,
                subtitle: _suggestions[i].fullAddress,
                onTap: _loading ? null : () => _pickSuggestion(_suggestions[i]),
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
          // Siempre a mano mientras se escribe: si no aparece, se marca.
          if (typing && !shortQuery)
            Padding(
              padding: const EdgeInsets.only(top: GSSpacing.s2),
              child: GSGroup(children: [
                GSListRow(
                  icon: Icons.pin_drop_rounded,
                  title: 'Elegir en el mapa',
                  subtitle: '¿No aparece? Mueve el pin hasta el punto exacto',
                  onTap: () => _adjustOnMap(editing),
                ),
              ]),
            ),
          if (typing && editing == _Field.dest && shortQuery)
            Padding(
              padding: const EdgeInsets.only(top: GSSpacing.s2),
              child: GSGroup(children: [
                GSListRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Pregúntale al asistente',
                  subtitle: '"¿Cómo llego al terminal de Maicao?"',
                  onTap: () => context.push(AppRoutes.aiChat),
                ),
              ]),
            ),

          // ── Los dos puntos listos: en qué ir ────────────────────────────
          if (ready) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s1, GSSpacing.s4, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: GSSize.iconSm, color: GSColors.textMuted),
                  const SizedBox(width: GSSpacing.s1),
                  Expanded(
                    child: Text(
                      _originIsMe
                          ? 'Te recogemos donde marca tu GPS. ¿No es exacto?'
                          : 'Te recogemos en el punto que elegiste.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _adjustOnMap(_Field.origin),
                    child: const Text('Ajustar'),
                  ),
                ],
              ),
            ),
            const GSSectionTitle('Elige cómo ir'),
            ModeOptions(
              from: _originLatLng!,
              to: _destLatLng!,
              selected: mode,
              onChanged: (m) {
                _rideKey = const Uuid().v4();
                ref.read(selectedModeProvider.notifier).state = m;
              },
            ),
          ] else if (!typing) ...[
            const GSSectionTitle('¿En qué vas?'),
            ModeSelector(
              selected: mode,
              onChanged: (m) =>
                  ref.read(selectedModeProvider.notifier).state = m,
            ),
          ],
        ],
      ),
      bottomNavigationBar: ready
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: GSColors.surface,
                boxShadow: GSShadow.sheet,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, GSSpacing.s3),
                  child: _primaryAction(mode),
                ),
              ),
            )
          : null,
    );
  }

  Widget _primaryAction(String mode) {
    if (_isRide(mode)) {
      final q = _quote(mode);
      final what = mode == 'Taxi' ? 'taxi' : 'mototaxi';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GSButton(
            label: q == null ? 'Pedir $what' : 'Pedir $what · ${formatCop(q.fare)}',
            leadingIcon: modeIconFor(mode),
            size: GSButtonSize.lg,
            isLoading: _loading,
            onPressed: _loading || q == null ? null : () => _requestNow(mode),
          ),
          const SizedBox(height: GSSpacing.s1),
          Text(
            mode == 'Taxi'
                ? 'Tarifa oficial. Pagas en efectivo al llegar.'
                : 'Tarifa sugerida: mientras buscamos puedes subirla. '
                    'Pagas en efectivo al llegar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    return GSButton(
      label: 'Ver ruta',
      leadingIcon: Icons.near_me_rounded,
      isLoading: _loading,
      onPressed: _loading ? null : _search,
    );
  }
}

enum _Dot { origin, dest }

/// Una fila de la tarjeta: recogida o destino. Escribiendo es un campo; si
/// no, el punto elegido, que se toca para cambiarlo.
class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.dot,
    required this.label,
    required this.value,
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onTap,
    this.onClose,
    this.placeholder = false,
    this.autofocus = false,
  });

  final _Dot dot;
  final String label;
  final String value;
  final bool editing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onTap;

  /// Dejar de escribir y volver a lo que había (null = no hay a qué volver).
  final VoidCallback? onClose;
  final bool placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final marker = SizedBox(
      width: 28,
      child: Center(
        child: dot == _Dot.origin
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GSColors.brand, width: 3),
                ),
              )
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: GSColors.text,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
      ),
    );
    if (editing) {
      final style = TextStyle(
        fontFamily: GSFonts.sans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: GSColors.text,
      );
      return Row(
        children: [
          marker,
          const SizedBox(width: GSSpacing.s2),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.search,
              style: style,
              decoration: InputDecoration(
                isDense: true,
                labelText: label,
                hintText: hint,
                hintStyle: style.copyWith(color: GSColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: GSSpacing.s3),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: controller.clear,
                      )
                    : onClose == null
                        ? null
                        : IconButton(
                            tooltip: 'Listo',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClose,
                          ),
              ),
            ),
          ),
        ],
      );
    }
    return GSPressable(
      onTap: onTap,
      semanticLabel: '$label: $value. Toca para cambiarlo',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GSSize.touchTarget + 8),
        child: Row(
          children: [
            marker,
            const SizedBox(width: GSSpacing.s2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: GSSpacing.s2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelSmall),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                          color: placeholder ? GSColors.textMuted : null),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s1),
              child: Icon(Icons.edit_rounded,
                  size: GSSize.iconSm, color: GSColors.textMuted),
            ),
          ],
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
