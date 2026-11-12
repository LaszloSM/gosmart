// lib/features/trip/trip_history_screen.dart
// Historial de viajes (estilo InDrive): TODO lo que la persona hizo, del más
// nuevo al más viejo, por tandas de 20 al bajar (my_trip_history, 026):
// completados, cancelados, los que nadie aceptó y los hechos como conductor.
// Cada uno dice de dónde a dónde, en qué, cómo terminó, con quién y cuánto.
// Tocarlo abre el detalle; "Pedir de nuevo" abre el planificador listo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/money.dart';
import '../../models/trip_history.dart';
import '../../providers/active_route_provider.dart';
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
  final Future<List<HistoryItem>> Function(int offset)? load;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  static const _page = 20;
  final _items = <HistoryItem>[];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _done = false;
  bool _failed = false;

  Future<List<HistoryItem>> _fetch(int offset) =>
      widget.load?.call(offset) ??
      dispatchService.history(offset: offset, limit: _page);

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
      final next = await _fetch(_items.length);
      if (!mounted) return;
      setState(() {
        // Sin repetidos si algo cambió entre páginas.
        final seen = {for (final i in _items) '${i.kind}:${i.id}'};
        _items.addAll(next.where((i) => seen.add('${i.kind}:${i.id}')));
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
      _items.clear();
      _done = false;
    });
    await _more();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty && _failed) {
      body = GSEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tus viajes',
        subtitle: 'Revisa tu conexión e intenta de nuevo.',
        actionLabel: 'Reintentar',
        onAction: _more,
      );
    } else if (_items.isEmpty) {
      body = GSEmptyState(
        icon: Icons.route_rounded,
        title: 'Aún no tienes viajes',
        subtitle:
            'Cuando pidas tu primer viaje, aquí queda todo: también los cancelados.',
        actionLabel: '¿A dónde vas?',
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
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: GSSpacing.s2),
          itemBuilder: (context, i) {
            if (i == _items.length) {
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
              return Padding(
                padding: const EdgeInsets.all(GSSpacing.s4),
                child: Text(
                  _items.length == 1 ? '1 viaje' : '${_items.length} viajes',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return TripHistoryTile(item: _items[i]);
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

/// Abre el planificador con el mismo origen y destino ("Pedir de nuevo").
void repeatTrip(BuildContext context, WidgetRef ref, HistoryItem item) {
  final from = item.from, to = item.to;
  if (from == null || to == null) return;
  ref.read(pendingPlanProvider.notifier).state = PlannerPreset(
    origin: from,
    originLabel: item.originLabel ?? 'Salida del viaje anterior',
    dest: to,
    destLabel: item.destLabel ?? 'Destino del viaje anterior',
  );
  context.push(AppRoutes.routePlanner);
}

/// Color e ícono del estado: marca para lo activo, tinta para lo hecho y
/// gris para lo cancelado (rojo/verde son solo de la vía).
(IconData, Color) historyToneStyle(HistoryTone t) => switch (t) {
      HistoryTone.done => (Icons.check_circle_rounded, GSColors.text),
      HistoryTone.active => (Icons.navigation_rounded, GSColors.brand),
      HistoryTone.cancelled => (Icons.cancel_rounded, GSColors.textMuted),
    };

/// Un viaje del historial.
class TripHistoryTile extends ConsumerWidget {
  const TripHistoryTile({super.key, required this.item});
  final HistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final t = item;
    final (statusLabel, tone) = t.statusText;
    final (statusIcon, statusColor) = historyToneStyle(tone);
    final price = t.price;
    final ride = t.ride;
    final who = ride?.otherName == null
        ? null
        : t.asDriver
            ? 'Llevaste a ${ride!.otherName}'
            : [ride!.otherName!, if (ride.plate != null) ride.plate!].join(' · ');
    final modes = <String>[
      for (final m in t.modes)
        if (m != 'walk') m,
    ];

    return Semantics(
      button: true,
      child: Material(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.tripDetail, extra: t),
          child: Padding(
            padding: const EdgeInsets.all(GSSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          t.createdAt == null ? 'Viaje' : tripWhen(t.createdAt!),
                          if (t.asDriver) 'Como conductor',
                        ].join(' · '),
                        // Con el precio al lado: aire entre los dos.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge
                            ?.copyWith(color: GSColors.textMuted),
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(width: GSSpacing.s3),
                      Text(formatCop(price),
                          style: text.titleMedium
                              ?.copyWith(fontFeatures: GSFonts.tabular)),
                    ],
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
                    for (final m in modes.isEmpty ? const ['walk'] : modes.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: GSSpacing.s1),
                        child: Tooltip(
                          message: legModeLabel(m),
                          child: Icon(legModeIcon(m),
                              size: GSSize.iconMd, color: GSColors.text),
                        ),
                      ),
                    const SizedBox(width: GSSpacing.s1),
                    Icon(statusIcon, size: GSSize.iconSm, color: statusColor),
                    const SizedBox(width: GSSpacing.s1),
                    Expanded(
                      child: Text(
                        who == null ? statusLabel : '$statusLabel · $who',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(color: statusColor),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: GSColors.textMuted),
                  ],
                ),
                // Repetir en un toque, en su propia línea (no aprieta el estado).
                if (t.canRepeat && tone != HistoryTone.active)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => repeatTrip(context, ref, t),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s1),
                          minimumSize: const Size(0, GSSize.touchTarget)),
                      icon: const Icon(Icons.replay_rounded, size: GSSize.iconSm),
                      label: const Text('Pedir de nuevo'),
                    ),
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
