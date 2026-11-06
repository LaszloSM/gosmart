// lib/features/trip/trip_history_screen.dart
// Historial de viajes: todos los viajes de la persona, del más nuevo al más
// viejo, por tandas de 20 al bajar. Cada uno dice de dónde a dónde, en qué
// fue (íconos de los tramos), cómo terminó y lo pagado. Los terminados abren
// su recibo; el que está en curso lleva a la pestaña Viaje.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/money.dart';
import '../../models/dispatch_models.dart';
import '../../router/app_router.dart';
import '../../services/dispatch_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_empty_state.dart';
import 'trip_screen.dart' show legModeIcon, legModeLabel;

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "Hoy, 3:40 p. m.", "Ayer, …" o "5 nov 2026, …" (a mano: sin
/// initializeDateFormatting, ver CLAUDE.md).
String tripWhen(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  final d = switch (diff) {
    0 => 'Hoy',
    1 => 'Ayer',
    _ =>
      '${t.day} ${_months[t.month - 1]}${t.year == n.year ? '' : ' ${t.year}'}',
  };
  return '$d, ${formatClock(t)}';
}

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key, this.load});

  /// Para pruebas: de dónde salen las páginas.
  final Future<List<ChainedTrip>> Function(int offset)? load;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  static const _page = 20;
  final _trips = <ChainedTrip>[];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _done = false;
  bool _failed = false;

  Future<List<ChainedTrip>> _fetch(int offset) =>
      widget.load?.call(offset) ??
      dispatchService.tripHistory(offset: offset, limit: _page);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final next = await _fetch(_trips.length);
      if (!mounted) return;
      setState(() {
        _trips.addAll(next);
        _done = next.length < _page;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _trips.clear();
      _done = false;
    });
    await _more();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_trips.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_trips.isEmpty && _failed) {
      body = GSEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tus viajes',
        subtitle: 'Revisa tu conexión e intenta de nuevo.',
        actionLabel: 'Reintentar',
        onAction: _more,
      );
    } else if (_trips.isEmpty) {
      body = GSEmptyState(
        icon: Icons.route_rounded,
        title: 'Aún no tienes viajes',
        subtitle:
            'Cuando hagas tu primer viaje, aquí queda el registro con su recibo.',
        actionLabel: 'Planear un viaje',
        onAction: () => context.push(AppRoutes.routePlanner),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, GSSpacing.s8),
          itemCount: _trips.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: GSSpacing.s2),
          itemBuilder: (context, i) {
            if (i == _trips.length) {
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(GSSpacing.s4),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_failed) {
                return TextButton(
                    onPressed: _more, child: const Text('Reintentar'));
              }
              return const SizedBox.shrink();
            }
            return TripHistoryTile(trip: _trips[i]);
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Historial de viajes')),
      body: body,
    );
  }
}

/// Un viaje del historial.
class TripHistoryTile extends StatelessWidget {
  const TripHistoryTile({super.key, required this.trip});
  final ChainedTrip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = trip;
    final (statusLabel, statusIcon) = switch (t.status) {
      'completed' => ('Completado', Icons.check_circle_rounded),
      'cancelled' => ('Cancelado', Icons.cancel_rounded),
      'in_progress' => ('En curso', Icons.navigation_rounded),
      _ => ('Planeado', Icons.schedule_rounded),
    };
    final active = !t.isFinished;
    final modes = <String>[
      for (final l in t.legs)
        if (l.mode != 'walk') l.mode,
    ];
    final paid = t.paidTotal;
    final VoidCallback? onTap = switch (t.status) {
      'completed' => () => context.push('${AppRoutes.receipt}?id=${t.id}'),
      'planned' || 'in_progress' => () => context.go(AppRoutes.trip),
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      child: Material(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(GSSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.createdAt == null ? 'Viaje' : tripWhen(t.createdAt!),
                        style: text.labelLarge
                            ?.copyWith(color: GSColors.textMuted),
                      ),
                    ),
                    Icon(statusIcon,
                        size: GSSize.iconSm,
                        color: active ? GSColors.brand : GSColors.textMuted),
                    const SizedBox(width: GSSpacing.s1),
                    Text(statusLabel,
                        style: text.labelLarge?.copyWith(
                            color:
                                active ? GSColors.brand : GSColors.textMuted)),
                  ],
                ),
                const SizedBox(height: GSSpacing.s2),
                _Place(
                    icon: Icons.trip_origin_rounded,
                    label: t.originLabel ?? 'Salida'),
                const SizedBox(height: GSSpacing.s1),
                _Place(
                    icon: Icons.location_on_rounded,
                    label: t.destLabel ?? 'Destino'),
                const SizedBox(height: GSSpacing.s3),
                Row(
                  children: [
                    for (final m in modes.isEmpty ? const ['walk'] : modes)
                      Padding(
                        padding: const EdgeInsets.only(right: GSSpacing.s2),
                        child: Tooltip(
                          message: legModeLabel(m),
                          child: Icon(legModeIcon(m),
                              size: GSSize.iconMd, color: GSColors.text),
                        ),
                      ),
                    const Spacer(),
                    if (paid > 0)
                      Text(formatCop(paid),
                          style: text.titleMedium
                              ?.copyWith(fontFeatures: GSFonts.tabular)),
                    if (onTap != null) ...[
                      const SizedBox(width: GSSpacing.s1),
                      Icon(Icons.chevron_right_rounded,
                          color: GSColors.textMuted),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: GSSize.iconSm, color: GSColors.textMuted),
          const SizedBox(width: GSSpacing.s2),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      );
}
