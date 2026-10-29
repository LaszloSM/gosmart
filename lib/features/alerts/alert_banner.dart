// lib/features/alerts/alert_banner.dart
// "Te estás acercando a…": cuando vas en movimiento y quedas a menos de
// 400 m de una alerta de un tipo que pediste que te avise, baja un aviso
// arriba del mapa (como Waze), se queda 6 s y se va. Una vez por alerta.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_alert.dart';
import '../../providers/map_alerts_provider.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_alert_badge.dart';
import 'alert_detail_sheet.dart';

/// La alerta más cercana a [at] (a menos de [radius] m) que aún no se avisó.
MapAlert? nextAlertToWarn(LatLng at, List<MapAlert> alerts,
    Map<String, AlertPref> prefs, Set<String> warned,
    {double radius = 400}) {
  const dist = Distance();
  MapAlert? best;
  var bestD = double.infinity;
  for (final a in alerts) {
    if (warned.contains(a.id) || a.mine) continue;
    if (!(prefs[a.kind.id]?.warn ?? true)) continue;
    final d = dist.as(LengthUnit.Meter, at, a.at);
    if (d < radius && d < bestD) {
      best = a;
      bestD = d;
    }
  }
  return best;
}

class AlertProximityBanner extends ConsumerStatefulWidget {
  const AlertProximityBanner({super.key, this.positions});

  /// Posiciones (en pruebas); por defecto, el GPS mientras te mueves.
  final Stream<LatLng>? positions;

  @override
  ConsumerState<AlertProximityBanner> createState() => _AlertProximityBannerState();
}

class _AlertProximityBannerState extends ConsumerState<AlertProximityBanner> {
  StreamSubscription<LatLng>? _sub;
  final _warned = <String>{};
  MapAlert? _current;
  int _meters = 0;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _sub = (widget.positions ?? locationService.watch()).listen(_onPosition);
  }

  void _onPosition(LatLng at) {
    final alerts = ref.read(mapAlertsProvider).valueOrNull ?? const <MapAlert>[];
    final next = nextAlertToWarn(at, alerts, ref.read(alertPrefsProvider), _warned);
    if (next == null || !mounted) return;
    _warned.add(next.id);
    setState(() {
      _current = next;
      _meters = (const Distance().as(LengthUnit.Meter, at, next.at) / 10).round() * 10;
    });
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final a = _current;
    // Entra desde arriba en 280 ms; sale más rápido (200 ms) por el mismo lado.
    return AnimatedSlide(
      offset: a == null ? const Offset(0, -1.6) : Offset.zero,
      duration: reduce ? Duration.zero : (a == null ? GSDuration.sheetOut : const Duration(milliseconds: 280)),
      curve: a == null ? GSCurve.exit : GSCurve.enter,
      child: AnimatedOpacity(
        opacity: a == null ? 0 : 1,
        duration: reduce ? Duration.zero : GSDuration.fast,
        child: a == null ? const SizedBox(height: 72) : _card(context, a),
      ),
    );
  }

  Widget _card(BuildContext context, MapAlert a) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      label: '${a.kind.label} a $_meters metros',
      child: Material(
        color: GSColors.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(GSRadius.lg),
          onTap: () {
            setState(() => _current = null);
            showAlertDetail(context, a);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(GSSpacing.s3, GSSpacing.s3, GSSpacing.s2, GSSpacing.s3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GSRadius.lg),
              boxShadow: GSShadow.float,
            ),
            child: Row(
              children: [
                GSAlertBadge(kind: a.kind, size: 44),
                const SizedBox(width: GSSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${a.kind.label} a $_meters m',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontFeatures: GSFonts.tabular)),
                      Text('Reportado ${alertAge(a.happenedAt)} · toca para ver',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar aviso',
                  icon: Icon(Icons.close_rounded, color: GSColors.textMuted),
                  onPressed: () => setState(() => _current = null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
