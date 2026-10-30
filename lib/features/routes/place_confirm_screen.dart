// lib/features/routes/place_confirm_screen.dart
// Confirmar el punto en el mapa (como Uber/DiDi): el pin queda fijo en el
// centro y la persona mueve el mapa hasta la entrada exacta. Es la última
// defensa contra un punto mal ubicado (lugar aproximado o Google equivocado).
// Devuelve el lugar con el punto confirmado; null = volvió sin confirmar.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/geocode_suggestion.dart';
import '../../services/geocoding_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../home/widgets/map_view.dart';

/// Menos que esto desde el punto elegido sigue siendo el mismo lugar.
const _sameSpotMeters = 30.0;

/// Lo que se le pasa a la ruta en `extra`: el lugar y los textos del uso.
class PlaceConfirmRequest {
  const PlaceConfirmRequest(this.place,
      {this.title = 'Confirma el destino',
      this.actionLabel = 'Confirmar destino'});
  final GeocodeSuggestion place;
  final String title;
  final String actionLabel;
}

class PlaceConfirmScreen extends StatefulWidget {
  const PlaceConfirmScreen({
    super.key,
    required this.place,
    this.title = 'Confirma el destino',
    this.actionLabel = 'Confirmar destino',
    this.reverse,
  });

  final GeocodeSuggestion place;
  final String title;
  final String actionLabel;

  /// Dirección de un punto; por defecto Google vía `maps` (inyectable en pruebas).
  final Future<String?> Function(LatLng)? reverse;

  @override
  State<PlaceConfirmScreen> createState() => _PlaceConfirmScreenState();
}

class _PlaceConfirmScreenState extends State<PlaceConfirmScreen> {
  late LatLng _center = widget.place.latLng!;
  bool _moving = false;
  String? _movedAddress; // dirección del punto nuevo, si se movió
  bool _looking = false; // buscando la dirección del punto nuevo
  int _lookup = 0;

  bool get _moved => _meters(widget.place.latLng!, _center) > _sameSpotMeters;

  void _onMoveStarted() {
    if (!_moving) setState(() => _moving = true);
  }

  Future<void> _onIdle(LatLng at) async {
    final id = ++_lookup;
    setState(() {
      _moving = false;
      _center = at;
      _movedAddress = null;
      _looking = _moved;
    });
    if (!_moved) return;
    final address = await (widget.reverse ?? geocodingService.reverse)(at);
    if (!mounted || id != _lookup) return;
    setState(() {
      _looking = false;
      _movedAddress = address;
    });
  }

  void _confirm() {
    final p = widget.place;
    final GeocodeSuggestion result;
    if (_moved) {
      result = GeocodeSuggestion(
        placeName: _movedAddress ?? 'Punto en el mapa',
        fullAddress:
            _movedAddress == null ? 'Cerca de ${p.placeName}' : p.fullAddress,
        latLng: _center,
        featureType: 'address',
      );
    } else {
      // Mismo lugar: la persona lo vio en el mapa y lo dio por bueno.
      result = GeocodeSuggestion(
        placeName: p.placeName,
        fullAddress: p.fullAddress,
        latLng: _center,
        placeId: p.placeId,
        featureType: p.featureType,
        fromDirectory: p.fromDirectory,
      );
    }
    context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = widget.place;
    final name = _moved ? (_movedAddress ?? 'Punto en el mapa') : p.placeName;
    final detail = _moved
        ? (_looking ? 'Buscando la dirección…' : 'Cerca de ${p.placeName}')
        : p.fullAddress;

    return Scaffold(
      backgroundColor: GSColors.background,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapView(
                    initialCenter: p.latLng!,
                    initialZoom: 17.5,
                    onCreated: (_) {},
                    onLongPress: (_) {},
                    onLongPressEnabled: false,
                    onCameraMoveStarted: _onMoveStarted,
                    onCameraIdle: _onIdle,
                  ),
                ),
                // El pin no es un marcador: está encima del mapa, en el centro.
                IgnorePointer(
                  child: Center(
                    child: Semantics(
                      label: 'Punto elegido, en el centro del mapa',
                      child: _CenterPin(lifted: _moving),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(GSSpacing.s4),
                    child: _BackButton(onTap: () => context.pop()),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: GSColors.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(GSRadius.xl)),
              boxShadow: GSShadow.sheet,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s5, GSSpacing.s4, GSSpacing.s3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Con texto grande la hoja se desplaza y el mapa sigue a la
                    // vista; el botón queda siempre abajo.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(widget.title, style: text.titleLarge),
                            const SizedBox(height: GSSpacing.s1),
                            Text(
                              'Mueve el mapa si el punto no está en la entrada.',
                              style: text.bodyMedium
                                  ?.copyWith(color: GSColors.textMuted),
                            ),
                            const SizedBox(height: GSSpacing.s4),
                            _PlaceLine(name: name, detail: detail),
                            if (p.approximate && !_moved) ...[
                              const SizedBox(height: GSSpacing.s3),
                              const _ApproxNotice(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: GSSpacing.s4),
                    GSButton(
                      label: widget.actionLabel,
                      isFullWidth: true,
                      isLoading: _looking,
                      onPressed: _moving || _looking ? null : _confirm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pin en tinta (el destino en todo el mapa es tinta; el rojo es de la vía).
/// Al mover el mapa se levanta y su sombra queda en el punto.
class _CenterPin extends StatelessWidget {
  const _CenterPin({required this.lifted});
  final bool lifted;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final duration = reduce ? Duration.zero : GSDuration.fast;
    // La punta del ícono queda a 4/48 del borde de abajo: con este relleno la
    // punta cae justo en el centro del mapa.
    return Padding(
      padding: const EdgeInsets.only(bottom: _size - 8),
      child: SizedBox(
        width: _size,
        height: _size + 8,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Sombra en el suelo, centrada en la punta: marca el punto exacto
            // aunque el pin suba.
            Positioned(
              bottom: 5,
              child: AnimatedContainer(
                duration: duration,
                curve: GSCurve.enter,
                width: lifted ? 8 : 12,
                height: lifted ? 4 : 6,
                decoration: BoxDecoration(
                  color: GSColors.text.withValues(alpha: lifted ? 0.35 : 0.25),
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: duration,
              curve: GSCurve.enter,
              bottom: lifted ? 14 : 4,
              // Sombra corta: se lee sobre calles, parques o agua.
              child: Icon(Icons.location_on_rounded,
                  size: _size,
                  color: GSColors.text,
                  shadows: [
                    Shadow(
                        color: GSColors.palette.shadowInk.withValues(alpha: 0.35),
                        offset: const Offset(0, 2),
                        blurRadius: 6),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.name, required this.detail});
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: GSSize.touchTarget,
          height: GSSize.touchTarget,
          decoration: BoxDecoration(
            color: GSColors.surfaceSunken,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on_rounded,
              size: GSSize.iconMd, color: GSColors.text),
        ),
        const SizedBox(width: GSSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (detail.isNotEmpty)
                Text(detail,
                    style: text.bodySmall?.copyWith(color: GSColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

/// Google no respondió y quedó el punto de nuestro directorio: decirlo claro.
class _ApproxNotice extends StatelessWidget {
  const _ApproxNotice();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surfaceSunken,
        borderRadius: BorderRadius.circular(GSRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: GSSize.iconMd, color: GSColors.text),
          const SizedBox(width: GSSpacing.s2),
          Expanded(
            child: Text(
              'Ubicación aproximada. Revisa que el pin esté en el lugar '
              'antes de confirmar.',
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: GSColors.surface,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: GSSize.touchTarget,
            height: GSSize.touchTarget,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: GSShadow.float,
            ),
            child: Semantics(
              button: true,
              label: 'Volver',
              child: Icon(Icons.arrow_back_rounded,
                  size: GSSize.iconLg, color: GSColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

double _meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final x = dLng * math.cos((a.latitude + b.latitude) * math.pi / 360);
  return r * math.sqrt(dLat * dLat + x * x);
}
