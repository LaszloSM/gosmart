import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_skeleton_loader.dart';
import '../../router/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/location_service.dart';
import '../../providers/selected_mode_provider.dart';
import 'widgets/quick_places_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedMode = 'Auto';
  final _sheetCtrl = DraggableScrollableController();

  static const _modes = [
    _Mode('Auto', Icons.directions_car_rounded, GSColors.car),
    _Mode('Taxi', Icons.local_taxi_rounded, GSColors.taxi),
    _Mode('Bus', Icons.directions_bus_rounded, GSColors.bus),
    _Mode('Bici', Icons.pedal_bike_rounded, GSColors.bike),
    _Mode('Metro', Icons.subway_rounded, GSColors.metro),
  ];

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.history);
        break;
      case 2:
        context.go(AppRoutes.wallet);
        break;
      case 3:
        context.go(AppRoutes.profile);
        break;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Buenos días';
    if (hour >= 12 && hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _initials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '?';
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _modeColor(String? mode) {
    switch (mode) {
      case 'car':
        return GSColors.car;
      case 'taxi':
        return GSColors.taxi;
      case 'bus':
        return GSColors.bus;
      case 'bike':
        return GSColors.bike;
      case 'walk':
        return GSColors.walk;
      case 'metro':
        return GSColors.metro;
      default:
        return GSColors.accent;
    }
  }

  IconData _modeIcon(String? mode) {
    switch (mode) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'bike':
        return Icons.pedal_bike_rounded;
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'metro':
        return Icons.subway_rounded;
      default:
        return Icons.commute_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final txDate = DateTime(local.year, local.month, local.day);
    final diff = todayDate.difference(txDate).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${local.day}/${local.month}/${local.year}';
  }

  String _formatAmount(TransactionModel t) {
    if (t.currency == 'COP') {
      final formatted = t.amount
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
      return '\$$formatted COP';
    }
    return t.amount.toStringAsFixed(2);
  }

  Widget _buildTripItem(TransactionModel t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _modeColor(t.mode).withValues(alpha: 0.15),
            child: Icon(
              _modeIcon(t.mode),
              color: _modeColor(t.mode),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.destination ?? t.origin ?? 'Viaje',
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(t.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: GSColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(t),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: GSColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    ref.listen<RouteResult?>(activeRouteProvider, (prev, next) {
      if (!_sheetCtrl.isAttached) return;
      if (next != null && prev == null) {
        _sheetCtrl.animateTo(
          0.12,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      } else if (next == null && prev != null) {
        _sheetCtrl.animateTo(
          0.28,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.bg,
      body: Stack(
        children: [
          // ── Layer 1: Full-screen map ────────────────────────────────────────
          const Positioned.fill(
            child: _AppMap(),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE0A0E1A)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Layer 2: Top bar ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: GSColors.surfaceContainerHighest.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: GSShadow.card,
                    border: Border.all(
                      color: GSColors.accent.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: GSGradient.avatarRing,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: (GSSize.avatarMd / 2) - 2.5,
                          backgroundColor: GSColors.accentLight,
                          backgroundImage: profileAsync.valueOrNull?.avatarUrl != null
                              ? NetworkImage(profileAsync.valueOrNull!.avatarUrl!)
                              : null,
                          child: profileAsync.valueOrNull?.avatarUrl == null
                              ? Text(
                                  _initials(profileAsync.valueOrNull?.name),
                                  style: const TextStyle(
                                    color: GSColors.accentAlt,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: GSColors.textSecondary),
                          ),
                          profileAsync.when(
                                data: (p) => Text(
                                  p.name.isEmpty
                                      ? 'Bienvenido'
                                      : p.name.split(' ').first,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: GSColors.textPrimary,
                                      ),
                                ),
                                loading: () => const GSSkeletonLoader(
                                  width: 80,
                                  height: 16,
                                  radius: 8,
                                ),
                                error: (_, __) => Text(
                                  'Usuario',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                              ),
                        ],
                      ),
                      const Spacer(),
                      const IconButton(
                        icon: Icon(
                          Icons.notifications_rounded,
                          color: GSColors.textSecondary,
                          size: 24,
                        ),
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 3: DraggableScrollableSheet ──────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.28,
            minChildSize: 0.12,
            maxChildSize: 0.90,
            snap: true,
            snapSizes: const [0.12, 0.28, 0.80],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: GSColors.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(GSRadius.xxl),
                  ),
                  boxShadow: GSShadow.lg,
                  border: Border(
                    top: BorderSide(
                      color: GSColors.accent.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s4,
                    vertical: 0,
                  ),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                          top: 12,
                          bottom: 16,
                        ),
                        decoration: BoxDecoration(
                          color: GSColors.accent.withValues(alpha: 0.4),
                          borderRadius:
                              BorderRadius.circular(GSRadius.full),
                        ),
                      ),
                    ),

                    // Search bar
                    GSSearchBar(
                      hint: '¿A dónde vas?',
                      readOnly: true,
                      onTap: () => context.push(AppRoutes.routePlanner),
                    ),

                    const SizedBox(height: GSSpacing.s3),

                    // Accesos rápidos: Casa, Trabajo, favoritos
                    QuickPlacesRow(
                      onPlaceSelected: (place) {
                        ref
                            .read(favoritesNotifierProvider.notifier)
                            .incrementUseCount(place.id);
                        // Navegar al planificador con el lugar como destino
                        context.push(AppRoutes.routePlanner);
                      },
                    ),

                    const SizedBox(height: GSSpacing.s4),

                    // Mode chips
                    Text(
                      'Modo de viaje',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: GSColors.textSecondary),
                    ),
                    const SizedBox(height: GSSpacing.s2),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _modes.map((m) {
                          final isLast = m == _modes.last;
                          return Padding(
                            padding: EdgeInsets.only(right: isLast ? 0 : 8),
                            child: GSModeChip(
                              label: m.label,
                              icon: m.icon,
                              color: m.color,
                              isSelected: _selectedMode == m.label,
                              onTap: () {
                                setState(() => _selectedMode = m.label);
                                ref.read(selectedModeProvider.notifier).state = m.label;
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: GSSpacing.s4),

                    // Info cards row
                    Row(
                      children: [
                        Expanded(
                          child: ref.watch(activeCardProvider).when(
                                data: (card) => GSInfoCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  iconBgColor: GSColors.accent,
                                  title: 'Saldo',
                                  value: card?.formattedBalance ?? '\$0 COP',
                                  onTap: () =>
                                      context.go(AppRoutes.wallet),
                                ),
                                loading: () => const GSSkeletonLoader(
                                  width: double.infinity,
                                  height: 72,
                                  radius: 16,
                                ),
                                error: (_, __) => const GSInfoCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  iconBgColor: GSColors.accent,
                                  title: 'Saldo',
                                  value: '—',
                                ),
                              ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: profileAsync.when(
                                data: (p) => GSInfoCard(
                                  icon: Icons.eco_rounded,
                                  iconBgColor: GSColors.eco,
                                  title: 'Eco Points',
                                  value: '${p.formattedEcoPoints} pts',
                                ),
                                loading: () => const GSSkeletonLoader(
                                  width: double.infinity,
                                  height: 72,
                                  radius: 16,
                                ),
                                error: (_, __) => const GSInfoCard(
                                  icon: Icons.eco_rounded,
                                  iconBgColor: GSColors.eco,
                                  title: 'Eco Points',
                                  value: '0 pts',
                                ),
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: GSSpacing.s4),

                    // Recent trips header
                    Row(
                      children: [
                        Text(
                          'Viajes recientes',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.history),
                          style: TextButton.styleFrom(
                            foregroundColor: GSColors.accent,
                          ),
                          child: const Text('Ver todos'),
                        ),
                      ],
                    ),

                    // Recent trips list
                    ref.watch(transactionListProvider).when(
                          loading: () => const Column(
                            children: [
                              GSTransactionSkeleton(),
                              SizedBox(height: 8),
                              GSTransactionSkeleton(),
                              SizedBox(height: 8),
                              GSTransactionSkeleton(),
                            ],
                          ),
                          error: (_, __) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Error al cargar viajes',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: GSColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          data: (list) {
                            if (list.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                child: Text(
                                  'Sin viajes recientes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: GSColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return Column(
                              children: list
                                  .take(3)
                                  .map(_buildTripItem)
                                  .toList(),
                            );
                          },
                        ),

                    const SizedBox(height: GSSpacing.s4),

                    // AI promo card
                    InkWell(
                      onTap: () => context.push(AppRoutes.aiChat),
                      borderRadius: BorderRadius.circular(GSRadius.xl),
                      child: Container(
                        padding: const EdgeInsets.all(GSSpacing.s4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [GSColors.accent, GSColors.accentAlt],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(GSRadius.xl),
                        ),
                        child: Row(
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'IA Asistente',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Planifica con IA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(GSRadius.full),
                              ),
                              child: const Text(
                                'Chatear',
                                style: TextStyle(
                                  color: GSColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom padding so content clears nav bar
                    const SizedBox(height: 80 + GSSpacing.s6),
                  ],
                ),
              );
            },
          ),

          // ── Layer 4b: Route banner (above bottom nav) ──────────────────────
          Consumer(
            builder: (ctx, ref, _) {
              final route = ref.watch(activeRouteProvider);
              if (route == null) return const SizedBox.shrink();
              return Positioned(
                bottom: GSSize.bottomNav,
                left: 0,
                right: 0,
                child: _RouteBanner(route: route),
              );
            },
          ),

          // ── Layer 5: Bottom nav ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GSBottomNav(
              currentIndex: 0,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Real Map with GPS + Mapbox tiles + route polylines ───────────────────────

class _AppMap extends ConsumerStatefulWidget {
  const _AppMap();

  @override
  ConsumerState<_AppMap> createState() => _AppMapState();
}

class _AppMapState extends ConsumerState<_AppMap>
    with SingleTickerProviderStateMixin {
  static const _bogota = LatLng(4.7110, -74.0721);

  late final MapController _mapController;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  LatLng _userPosition = _bogota;
  LatLng? _longPressPoint;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Resolve GPS after first frame (avoids calling async in initState).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pos = await locationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() => _userPosition = pos);
        _mapController.move(pos, 14);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _recenter() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _userPosition = pos);
      _mapController.move(pos, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute = ref.watch(activeRouteProvider);

    // Auto-fit camera to route when a new route becomes active
    ref.listen<RouteResult?>(activeRouteProvider, (prev, next) {
      if (next != null && next.legs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final allPoints = next.legs.expand((l) => l.points).toList();
          if (allPoints.length > 1) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(allPoints),
                padding: const EdgeInsets.fromLTRB(40, 120, 40, 200),
              ),
            );
          }
        });
      }
    });

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userPosition,
            initialZoom: 14,
            minZoom: 5.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onLongPress: (tapPosition, point) {
              setState(() => _longPressPoint = point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: Env.mapboxToken.isNotEmpty
                  ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x'
                      '?access_token=${Env.mapboxToken}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileSize: Env.mapboxToken.isNotEmpty ? 512 : 256,
              zoomOffset: Env.mapboxToken.isNotEmpty ? -1 : 0,
              userAgentPackageName: 'com.gosmart.app',
              maxNativeZoom: 19,
            ),
            // Route polylines (shown when a route is active)
            if (activeRoute != null)
              PolylineLayer(
                polylines: activeRoute.legs
                    .map((leg) => Polyline(
                          points: leg.points,
                          strokeWidth: 5.0,
                          color: leg.color,
                          borderColor: Colors.black26,
                          borderStrokeWidth: 1.5,
                        ))
                    .toList(),
              ),
            // Destination pin (shown when a route is active)
            if (activeRoute != null && activeRoute.legs.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: activeRoute.legs.last.points.last,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GSColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: GSColors.error.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            // Origin marker (shown when a route is active)
            if (activeRoute != null && activeRoute.legs.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: activeRoute.legs.first.points.first,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GSColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: GSColors.accent.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                          Icons.my_location, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            // User location marker (blue pulsing dot)
            MarkerLayer(
              markers: [
                Marker(
                  point: _userPosition,
                  width: 60,
                  height: 60,
                  child: _PulsingMarker(pulse: _pulse, color: Colors.blue),
                ),
              ],
            ),
            // Long-press destination pin
            if (_longPressPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _longPressPoint!,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.orangeAccent,
                      size: 44,
                    ),
                  ),
                ],
              ),
          ],
        ),

        // "¿Ir aquí?" overlay when a long-press destination is selected
        if (_longPressPoint != null)
          Positioned(
            left: GSSpacing.s4,
            right: GSSpacing.s4,
            bottom: GSSize.bottomNav + GSSpacing.s4,
            child: _GoHereCard(
              point: _longPressPoint!,
              onConfirm: () {
                ref.read(pendingDestinationProvider.notifier).state =
                    _longPressPoint;
                setState(() => _longPressPoint = null);
                context.push(AppRoutes.routePlanner);
              },
              onCancel: () => setState(() => _longPressPoint = null),
            ),
          ),

        // FAB — re-center on user position (above bottom nav)
        Positioned(
          right: GSSpacing.s4,
          bottom: GSSize.bottomNav + GSSpacing.s4,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            backgroundColor: GSColors.primary,
            onPressed: _recenter,
            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

class _RouteBanner extends ConsumerWidget {
  const _RouteBanner({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s5, vertical: GSSpacing.s3),
      decoration: const BoxDecoration(
        color: GSColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.lg)),
      ),
      child: Row(
        children: [
          Icon(RouteProfile.iconFor(route.profile),
              color: RouteProfile.colorFor(route.profile), size: 20),
          const SizedBox(width: GSSpacing.s3),
          Text(
            '${route.durationMin} min · ${route.distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () =>
                ref.read(activeRouteProvider.notifier).state = null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker({required this.pulse, this.color = GSColors.accent});
  final Animation<double> pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: pulse,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.40),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── "¿Ir aquí?" card overlay ─────────────────────────────────────────────────

class _GoHereCard extends StatelessWidget {
  const _GoHereCard({
    required this.point,
    required this.onConfirm,
    required this.onCancel,
  });
  final LatLng point;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GSSpacing.s4,
        vertical: GSSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: GSColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(GSRadius.xl),
        boxShadow: GSShadow.lg,
        border: Border.all(
          color: GSColors.accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.orangeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Ir aquí?',
                  style: TextStyle(
                    color: GSColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    color: GSColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: GSColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s2),
              minimumSize: Size.zero,
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: GSSpacing.s1),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: GSColors.accent,
              foregroundColor: GSColors.bg,
              padding: const EdgeInsets.symmetric(
                horizontal: GSSpacing.s3,
                vertical: GSSpacing.s2,
              ),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Buscar ruta',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _Mode {
  final String label;
  final IconData icon;
  final Color color;
  const _Mode(this.label, this.icon, this.color);
}
