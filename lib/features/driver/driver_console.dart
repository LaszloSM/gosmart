// lib/features/driver/driver_console.dart
// Modo conductor aprobado, como InDrive: el mapa de fondo con tu posición,
// arriba el menú, lo que llevas hoy y cobrar con QR; abajo, en la zona del
// pulgar, "Conectarme" (72 dp) o, conectado, las solicitudes cercanas y el
// viaje en curso. Desde el menú se vuelve al modo pasajero.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/region.dart';
import '../../models/dispatch_models.dart';
import '../../models/driver_model.dart';
import '../../providers/driver_provider.dart';
import '../../providers/settings_provider.dart';
import '../../router/app_router.dart';
import '../../services/driver_service.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_pressable.dart';
import '../../widgets/gs_toast.dart';
import '../../widgets/gs_vehicle_pin.dart';
import '../home/widgets/map_view.dart';
import '../trip/widgets/trip_visuals.dart' show DriverAvatar;
import 'driver_work_panel.dart';

/// Pasar al modo pasajero: te desconecta (nadie te asigna viajes que no ves)
/// y vuelve al inicio.
Future<void> switchToPassenger(BuildContext context, WidgetRef ref, {DriverProfile? driver}) async {
  final router = GoRouter.of(context);
  if (driver != null && driver.available) {
    try {
      await driverService.setAvailable(driver.userId, false);
    } catch (_) {}
    ref.invalidate(myDriverProvider);
  }
  await ref.read(appModeProvider.notifier).set(AppMode.passenger);
  router.go(AppRoutes.home);
}

/// Pasar al modo conductor (desde el perfil o la configuración).
Future<void> switchToDriver(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  await ref.read(appModeProvider.notifier).set(AppMode.driver);
  router.go(AppRoutes.driver);
}

class DriverConsole extends ConsumerStatefulWidget {
  const DriverConsole({super.key, required this.driver});
  final DriverProfile driver;

  @override
  ConsumerState<DriverConsole> createState() => _DriverConsoleState();
}

class _DriverConsoleState extends ConsumerState<DriverConsole> {
  MapViewController? _map;
  LatLng? _me = locationService.last;
  RideRequest? _active;
  bool _toggling = false;

  Future<void> _setOnline(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _toggling = true);
    try {
      await driverService.setAvailable(widget.driver.userId, on);
      ref.invalidate(myDriverProvider);
      if (!on) ref.invalidate(driverEarningsProvider);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: on
              ? 'No pudimos conectarte. Revisa tu conexión.'
              : 'No pudimos desconectarte. Revisa tu conexión.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _onActive(RideRequest? r) {
    setState(() => _active = r);
    // Al entrar un viaje: que se vean tú y el punto donde vas.
    if (r != null) {
      final target = r.status == RideStatus.inProgress ? r.dest : r.origin;
      if (target != null) _map?.fit([if (_me != null) _me!, target]);
    } else {
      ref.invalidate(driverEarningsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final online = d.available;
    final top = MediaQuery.paddingOf(context).top;
    final a = _active;
    final pin = a == null ? null : (a.status == RideStatus.inProgress ? a.dest : a.origin);
    return Scaffold(
      backgroundColor: GSColors.background,
      body: LayoutBuilder(builder: (context, box) {
        final panelH = online ? box.maxHeight * 0.56 : 0.0;
        return Stack(
          children: [
            Positioned.fill(
              child: MapView(
                initialCenter: _me ?? GSRegion.riohacha,
                onCreated: (c) {
                  _map = c;
                  if (_me == null) {
                    locationService.getCurrentPosition().then((p) {
                      if (p != null && mounted) {
                        setState(() => _me = p);
                        c.moveTo(p);
                      }
                    });
                  }
                },
                onLongPress: (_) {},
                onLongPressEnabled: false,
                user: _me,
                pin: pin,
                padding: EdgeInsets.only(top: top + 64, bottom: online ? panelH : 220),
              ),
            ),
            Positioned(
              top: top + GSSpacing.s2,
              left: GSSpacing.s3,
              right: GSSpacing.s3,
              child: Row(
                children: [
                  _FloatButton(
                    tooltip: 'Menú del conductor',
                    icon: Icons.menu_rounded,
                    onTap: () => _showMenu(context),
                  ),
                  const SizedBox(width: GSSpacing.s2),
                  const Expanded(child: _EarningsPill()),
                  const SizedBox(width: GSSpacing.s2),
                  _FloatButton(
                    tooltip: 'Cobrar con QR',
                    icon: Icons.qr_code_2_rounded,
                    onTap: () => context.push(AppRoutes.driverCharge),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSwitcher(
                duration: MediaQuery.of(context).disableAnimations ? Duration.zero : GSDuration.normal,
                switchInCurve: GSCurve.enter,
                switchOutCurve: GSCurve.exit,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: online
                    ? Container(
                        key: const ValueKey('online'),
                        height: panelH,
                        decoration: BoxDecoration(
                          color: GSColors.background,
                          borderRadius: GSRadius.sheetRadius,
                          boxShadow: GSShadow.sheet,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: DriverWorkPanel(
                          driver: d,
                          onActive: _onActive,
                          onPosition: (p) {
                            if (_me == null) _map?.moveTo(p);
                            if (mounted) setState(() => _me = p);
                          },
                          header: [
                            _OnlineHeader(
                              busy: _toggling,
                              busyRide: a != null,
                              onDisconnect: () => _setOnline(false),
                            ),
                          ],
                        ),
                      )
                    : _OfflinePanel(
                        key: const ValueKey('offline'),
                        driver: d,
                        busy: _toggling,
                        onConnect: () => _setOnline(true),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showMenu(BuildContext context) {
    final d = widget.driver;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s3),
                child: Row(
                  children: [
                    DriverAvatar(name: d.fullName, size: 56),
                    const SizedBox(width: GSSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheet).textTheme.titleLarge),
                          Text(
                            [
                              driverServices[d.service] ?? d.service,
                              if (d.vehicle != null) d.vehicle!.plate,
                            ].join(' · '),
                            style: Theme.of(sheet).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GSGroup(children: [
                GSListRow(
                  icon: Icons.insights_rounded,
                  title: 'Ganancias',
                  subtitle: 'Hoy y los últimos 7 días',
                  onTap: () {
                    Navigator.pop(sheet);
                    showEarningsSheet(context);
                  },
                ),
                GSListRow(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Cobrar con QR',
                  subtitle: 'El pasajero escanea y paga con su saldo',
                  onTap: () {
                    Navigator.pop(sheet);
                    context.push(AppRoutes.driverCharge);
                  },
                ),
                GSListRow(
                  icon: Icons.badge_rounded,
                  title: 'Mis datos y vehículo',
                  subtitle: 'Si cambias algo revisado, vuelve a revisión',
                  onTap: () {
                    Navigator.pop(sheet);
                    context.push(AppRoutes.driverSignup);
                  },
                ),
                GSListRow(
                  icon: Icons.settings_rounded,
                  title: 'Configuración',
                  onTap: () {
                    Navigator.pop(sheet);
                    context.push(AppRoutes.settings);
                  },
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(GSSpacing.s4),
                child: GSButton(
                  label: 'Cambiar a modo pasajero',
                  leadingIcon: Icons.swap_horiz_rounded,
                  variant: GSButtonVariant.outline,
                  onPressed: () {
                    Navigator.pop(sheet);
                    switchToPassenger(context, ref, driver: d);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón redondo flotante (48 dp) sobre el mapa.
class _FloatButton extends StatelessWidget {
  const _FloatButton({required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GSPressable(
        onTap: onTap,
        semanticLabel: tooltip,
        child: Container(
          width: GSSize.touchTarget,
          height: GSSize.touchTarget,
          decoration: BoxDecoration(
            color: GSColors.surface,
            shape: BoxShape.circle,
            boxShadow: GSShadow.float,
          ),
          child: Icon(icon, color: GSColors.text),
        ),
      ),
    );
  }
}

/// Lo que llevas hoy, arriba al centro (como InDrive). Toca para el detalle.
class _EarningsPill extends ConsumerWidget {
  const _EarningsPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(driverEarningsProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return GSPressable(
      onTap: () => showEarningsSheet(context),
      semanticLabel: e == null ? 'Ganancias' : 'Hoy ${formatCop(e.todayTotal)}, ${e.todayTrips} viajes',
      child: Container(
        height: GSSize.touchTarget,
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.full),
          boxShadow: GSShadow.float,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hoy ', style: text.bodyMedium),
              Text(
                e == null ? '—' : formatCop(e.todayTotal),
                style: text.titleMedium?.copyWith(fontFeatures: GSFonts.tabular),
              ),
              if (e != null)
                Text(' · ${e.todayTrips} ${e.todayTrips == 1 ? 'viaje' : 'viajes'}',
                    style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desconectado: quién eres, lo de hoy y el botón grande de conectarse.
class _OfflinePanel extends ConsumerWidget {
  const _OfflinePanel({super.key, required this.driver, required this.busy, required this.onConnect});
  final DriverProfile driver;
  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final v = driver.vehicle;
    return Container(
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: GSRadius.sheetRadius,
        boxShadow: GSShadow.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s5, GSSpacing.s4, GSSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: GSColors.surfaceSunken, shape: BoxShape.circle),
                    child: Icon(Icons.power_settings_new_rounded, color: GSColors.textMuted),
                  ),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estás desconectado', style: text.titleLarge),
                        Text('Nadie te ve. Conéctate cuando quieras trabajar.',
                            style: text.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              if (v != null) ...[
                const SizedBox(height: GSSpacing.s3),
                Row(
                  children: [
                    Icon(vehicleIcon(driver.service), size: GSSize.iconMd, color: GSColors.textMuted),
                    const SizedBox(width: GSSpacing.s2),
                    Expanded(
                      child: Text(
                        [
                          'Placa ${v.plate}',
                          if ((v.brand ?? '').isNotEmpty) v.brand!,
                          if ((v.color ?? '').isNotEmpty) v.color!,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: GSSpacing.s4),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: GSSize.touchTargetDriver),
                child: GSButton(
                  label: 'Conectarme',
                  leadingIcon: Icons.power_settings_new_rounded,
                  size: GSButtonSize.driver,
                  isLoading: busy,
                  onPressed: busy ? null : onConnect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Conectado: punto de marca que late (se está buscando) y desconectarse.
class _OnlineHeader extends StatelessWidget {
  const _OnlineHeader({required this.busy, required this.busyRide, required this.onDisconnect});
  final bool busy;
  final bool busyRide;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s4, GSSpacing.s2, 0),
      child: Row(
        children: [
          const _LiveDot(),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conectado', style: text.titleLarge),
                Text(busyRide ? 'Tienes un viaje en curso' : 'Buscando solicitudes cerca',
                    style: text.bodyMedium),
              ],
            ),
          ),
          // Con un viaje en curso no se desconecta (el pasajero te espera).
          if (!busyRide)
            TextButton.icon(
              onPressed: busy ? null : onDisconnect,
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Desconectarme'),
            ),
        ],
      ),
    );
  }
}

/// Punto de "en línea": late suave mientras estás conectado (bucle solo
/// mientras se espera, y quieto con "quitar animaciones").
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: GSColors.brand,
        shape: BoxShape.circle,
        border: Border.all(color: GSColors.brandTint, width: 3),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 28,
        child: Center(child: SearchPulse(child: dot)),
      ),
    );
  }
}

/// Onda alrededor de un punto (1,6 s, en bucle).
class SearchPulse extends StatefulWidget {
  const SearchPulse({super.key, required this.child});
  final Widget child;

  @override
  State<SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<SearchPulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          if (_c.isAnimating)
            Container(
              width: 14 + 14 * Curves.easeOut.transform(_c.value),
              height: 14 + 14 * Curves.easeOut.transform(_c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GSColors.brand.withValues(alpha: 0.3 * (1 - _c.value)),
              ),
            ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}

/// Ganancias: lo de hoy en grande, cuánto por la app y cuánto en efectivo,
/// la semana y tu calificación. Sin cifras inventadas si no hay datos.
Future<void> showEarningsSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _EarningsSheet(),
    );

class _EarningsSheet extends ConsumerWidget {
  const _EarningsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(driverEarningsProvider);
    final e = async.valueOrNull;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s4),
        child: async.isLoading && e == null
            ? const Padding(
                padding: EdgeInsets.all(GSSpacing.s6),
                child: Center(child: CircularProgressIndicator()),
              )
            : e == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: GSSpacing.s4),
                    child: Text('No pudimos cargar tus ganancias. Revisa tu conexión.',
                        style: text.bodyLarge),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Hoy', style: text.titleMedium),
                      Text(
                        formatCop(e.todayTotal),
                        style: TextStyle(
                          fontFamily: GSFonts.display,
                          fontFeatures: GSFonts.tabular,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: GSColors.text,
                        ),
                      ).gsEnter(context, scale: 0.96),
                      Text(
                        '${e.todayTrips} ${e.todayTrips == 1 ? 'viaje' : 'viajes'} · '
                        '${formatCop(e.todayApp)} por la app · ${formatCop(e.todayCash)} en efectivo',
                        style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular),
                      ),
                      const SizedBox(height: GSSpacing.s4),
                      GSGroup(children: [
                        GSListRow(
                          icon: Icons.date_range_rounded,
                          title: 'Últimos 7 días',
                          subtitle: '${e.weekTrips} ${e.weekTrips == 1 ? 'viaje' : 'viajes'} · '
                              '${formatCop(e.weekCash)} en efectivo',
                          value: formatCop(e.weekTotal),
                        ),
                        GSListRow(
                          icon: Icons.star_rounded,
                          title: e.rating == null
                              ? 'Aún sin calificación'
                              : 'Calificación ${e.rating!.toStringAsFixed(1).replaceAll('.', ',')}',
                          subtitle: e.rating == null
                              ? 'Aparece después de 3 viajes calificados'
                              : '${e.ratings} calificaciones',
                        ),
                      ]),
                      const SizedBox(height: GSSpacing.s3),
                      Text(
                        'Lo pagado con saldo llega a tu billetera de GoSmart. El efectivo '
                        'cuenta cuando confirmas que lo recibiste.',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
      ),
    );
  }
}
