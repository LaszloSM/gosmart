// lib/features/admin/admin_screen.dart
// Panel admin (Fase 8): misma app, ruta /admin, pensado también para Flutter
// Web en un computador. Solo para profiles.role = 'admin'; el servidor lo
// vuelve a comprobar en cada RPC (is_admin()).
//   Conductores: revisar datos y fotos de documentos; aprobar o rechazar.
//   Reportes: quitar los falsos o los que señalan a alguien.
//   Métricas: para Instramd y la Alcaldía, sin datos personales.
//   Ajustes: interruptores (despacho, Wompi).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../providers/profile_provider.dart';
import '../../services/trust_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import '../../models/driver_model.dart' show driverDocuments, driverServices, driverZones;
import '../../services/corridor_service.dart' show roadReportKinds;

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile == null || !profile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: ListView(children: const [
          GSEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Solo administradores',
            subtitle: 'Tu cuenta no tiene permiso para este panel.',
          ),
        ]),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: GSColors.background,
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: GSColors.onShell,
            unselectedLabelColor: GSColors.onShellMuted,
            indicatorColor: GSColors.stripe,
            indicatorWeight: 4,
            tabs: const [
              Tab(text: 'Conductores'),
              Tab(text: 'Reportes'),
              Tab(text: 'Métricas'),
              Tab(text: 'Ajustes'),
            ],
          ),
        ),
        body: Center(
          // En computador, columna de 1.200 px como máximo (DESIGN.md).
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: const TabBarView(children: [
              _DriversTab(),
              _ReportsTab(),
              _MetricsTab(),
              _FlagsTab(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Carga con reintento, sin repetir el patrón en cada pestaña.
class _Loader<T> extends StatefulWidget {
  const _Loader({super.key, required this.load, required this.builder, required this.what});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  final String what;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _f = widget.load();
  void _reload() => setState(() => _f = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.all(GSSpacing.s4),
              child: GSInlineError(
                  message: 'No pudimos cargar ${widget.what}', onRetry: _reload),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: widget.builder(context, s.data as T, _reload),
          );
        },
      );
}

// ── Conductores ──────────────────────────────────────────────────────────────
class _DriversTab extends StatelessWidget {
  const _DriversTab();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<AdminDriverRow>>(
      what: 'los conductores',
      load: trustService.driverQueue,
      builder: (context, rows, reload) => rows.isEmpty
          ? ListView(children: const [
              GSEmptyState(icon: Icons.badge_outlined, title: 'Sin registros'),
            ])
          : ListView(
              children: [
                for (final d in rows) ...[
                  GSListRow(
                    icon: d.status == 'pending'
                        ? Icons.hourglass_top_rounded
                        : d.status == 'approved'
                            ? Icons.verified_outlined
                            : Icons.block_rounded,
                    title: d.fullName,
                    subtitle: '${driverServices[d.service] ?? d.service} · '
                        '${driverZones[d.zone] ?? d.zone} · ${_statusWord(d.status)}'
                        '${d.plate == null ? '' : ' · ${d.plate}'}',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _DriverReview(driver: d, onDone: reload),
                    ),
                  ),
                  const Divider(indent: GSSpacing.s4),
                ],
              ],
            ),
    );
  }

  static String _statusWord(String s) => switch (s) {
        'pending' => 'por revisar',
        'approved' => 'aprobado',
        'rejected' => 'rechazado',
        'suspended' => 'suspendido',
        _ => s,
      };
}

class _DriverReview extends StatefulWidget {
  const _DriverReview({required this.driver, required this.onDone});
  final AdminDriverRow driver;
  final VoidCallback onDone;

  @override
  State<_DriverReview> createState() => _DriverReviewState();
}

class _DriverReviewState extends State<_DriverReview> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _open(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await trustService.documentUrl(widget.driver.userId, kind);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos abrir el documento.', type: GSToastType.error);
    }
  }

  Future<void> _decide(String status) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await trustService.reviewDriver(widget.driver.userId, status,
          note: _note.text.trim().isEmpty ? null : _note.text.trim());
      nav.pop();
      widget.onDone();
      GSToast.showWithMessenger(messenger, message: 'Guardado', type: GSToastType.success);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No se guardó. Revisa tu conexión.', type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(GSSpacing.s4, 0, GSSpacing.s4,
            GSSpacing.s4 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(d.fullName, style: text.titleLarge),
            Text('Cédula ${d.cedula} · ${d.phone}',
                style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular)),
            const SizedBox(height: GSSpacing.s3),
            for (final e in driverDocuments.entries)
              GSListRow(
                icon: d.documents.contains(e.key)
                    ? Icons.image_outlined
                    : Icons.remove_circle_outline_rounded,
                title: e.value,
                subtitle: d.documents.contains(e.key) ? 'Ver foto' : 'No subido',
                onTap: d.documents.contains(e.key) ? () => _open(e.key) : null,
              ),
            const SizedBox(height: GSSpacing.s3),
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Nota para el conductor (si rechazas)',
                hintText: 'Ej.: la licencia está vencida',
              ),
            ),
            const SizedBox(height: GSSpacing.s2),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide('rejected'),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide('approved'),
                  child: const Text('Aprobar'),
                ),
              ),
            ]),
            if (d.status == 'approved')
              TextButton(
                onPressed: _busy ? null : () => _decide('suspended'),
                child: const Text('Suspender'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Reportes ─────────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<AdminReportRow>>(
      what: 'los reportes',
      load: trustService.recentReports,
      builder: (context, rows, reload) => rows.isEmpty
          ? ListView(children: const [
              GSEmptyState(icon: Icons.campaign_outlined, title: 'Sin reportes en 72 h'),
            ])
          : ListView(children: [
              for (final r in rows) ...[
                GSListRow(
                  icon: r.removed ? Icons.delete_outline_rounded : Icons.campaign_outlined,
                  title: '${roadReportKinds[r.kind] ?? r.kind} · ${r.segmentId}',
                  subtitle: '${r.happenedAt.day}/${r.happenedAt.month} '
                      '${r.happenedAt.hour}:${r.happenedAt.minute.toString().padLeft(2, '0')} · '
                      '${r.confirmations} confirman, ${r.denials} desmienten'
                      '${r.removed ? ' · quitado' : ''}',
                  trailing: r.removed
                      ? null
                      : TextButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await trustService.removeReport(r.id);
                              reload();
                            } catch (_) {
                              GSToast.showWithMessenger(messenger,
                                  message: 'No se pudo quitar.', type: GSToastType.error);
                            }
                          },
                          child: const Text('Quitar'),
                        ),
                ),
                const Divider(indent: GSSpacing.s4),
              ],
            ]),
    );
  }
}

// ── Métricas ─────────────────────────────────────────────────────────────────
const _metricLabels = <String, String>{
  'reports': 'Reportes viales',
  'reports_confirmed': 'Reportes confirmados por otros',
  'reports_removed': 'Reportes quitados por moderación',
  'minutes_to_confirm': 'Minutos hasta la primera confirmación (mediana)',
  'rides_requested': 'Viajes pedidos',
  'rides_accepted': 'Viajes aceptados',
  'rides_completed': 'Viajes terminados',
  'median_seconds_to_accept': 'Segundos hasta que un conductor acepta (mediana)',
  'seats_reserved': 'Cupos de colectivo reservados',
  'payments_cop': 'Pagos registrados',
  'trips_completed': 'Viajes encadenados completos',
  'sos_events': 'Avisos de ayuda (SOS)',
  'drivers_approved': 'Conductores aprobados',
  'drivers_pending': 'Conductores por revisar',
};

class _MetricsTab extends StatefulWidget {
  const _MetricsTab();
  @override
  State<_MetricsTab> createState() => _MetricsTabState();
}

class _MetricsTabState extends State<_MetricsTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    return _Loader<Map<String, dynamic>>(
      key: ValueKey(_days),
      what: 'las métricas',
      load: () => trustService.metrics(_days),
      builder: (context, m, reload) {
        final requested = (m['rides_requested'] as num?) ?? 0;
        final accepted = (m['rides_accepted'] as num?) ?? 0;
        return ListView(children: [
          Padding(
            padding: const EdgeInsets.all(GSSpacing.s4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 días')),
                ButtonSegment(value: 30, label: Text('30 días')),
                ButtonSegment(value: 90, label: Text('90 días')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
          for (final e in _metricLabels.entries)
            GSListRow(
              icon: Icons.insights_rounded,
              title: e.value,
              value: m[e.key] == null
                  ? 'Sin datos'
                  : e.key == 'payments_cop'
                      ? formatCop(m[e.key] as num)
                      : '${m[e.key]}',
            ),
          GSListRow(
            icon: Icons.percent_rounded,
            title: 'Éxito del despacho',
            subtitle: 'Viajes aceptados sobre pedidos',
            value: requested == 0
                ? 'Sin datos'
                : '${(accepted * 100 / requested).round()} %',
          ),
        ]);
      },
    );
  }
}

// ── Ajustes ──────────────────────────────────────────────────────────────────
const _flagLabels = {
  'dispatch_enabled': ('Despacho de mototaxi y taxi', 'Apágalo si falla en el piloto: nadie podrá pedir.'),
  'wompi_enabled': ('Recargas reales con Wompi', 'Solo con las llaves configuradas en la Edge Function.'),
};

class _FlagsTab extends StatelessWidget {
  const _FlagsTab();

  @override
  Widget build(BuildContext context) {
    return _Loader<Map<String, bool>>(
      what: 'los ajustes',
      load: trustService.flags,
      builder: (context, flags, reload) => ListView(children: [
        for (final e in _flagLabels.entries)
          SwitchListTile(
            title: Text(e.value.$1),
            subtitle: Text(e.value.$2),
            value: flags[e.key] ?? false,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await trustService.setFlag(e.key, v);
                reload();
              } catch (_) {
                GSToast.showWithMessenger(messenger,
                    message: 'No se guardó.', type: GSToastType.error);
              }
            },
          ),
      ]),
    );
  }
}
