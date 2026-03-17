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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedMode = 'Auto';

  static const _modes = [
    _Mode('Auto', Icons.directions_car_rounded, GSColors.car),
    _Mode('Taxi', Icons.local_taxi_rounded, GSColors.taxi),
    _Mode('Bus', Icons.directions_bus_rounded, GSColors.bus),
    _Mode('Bici', Icons.pedal_bike_rounded, GSColors.bike),
    _Mode('Metro', Icons.subway_rounded, GSColors.metro),
  ];

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
                  colors: [Colors.transparent, Color(0xCC1A1A2E)],
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
                    color: const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: GSShadow.card,
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
            initialChildSize: 0.48,
            minChildSize: 0.12,
            maxChildSize: 0.90,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: GSColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(GSRadius.xxl),
                  ),
                  boxShadow: GSShadow.lg,
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
                              onTap: () =>
                                  setState(() => _selectedMode = m.label),
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

          // ── Layer 4: Bottom nav ─────────────────────────────────────────────
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

// ─── Real Map (OpenStreetMap via flutter_map) ─────────────────────────────────

class _AppMap extends StatefulWidget {
  const _AppMap();

  @override
  State<_AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<_AppMap> with SingleTickerProviderStateMixin {
  // Bogotá, Colombia — target city for GoSmart
  static const LatLng _bogota = LatLng(4.7110, -74.0721);

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: _bogota,
        initialZoom: 14,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
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
        MarkerLayer(
          markers: [
            Marker(
              point: _bogota,
              width: 60,
              height: 60,
              child: _PulsingMarker(pulse: _pulse),
            ),
          ],
        ),
      ],
    );
  }
}

class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker({required this.pulse});
  final Animation<double> pulse;

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
              color: GSColors.accent.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: GSColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: GSColors.accent.withValues(alpha: 0.40),
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

// ─── Data class ───────────────────────────────────────────────────────────────

class _Mode {
  final String label;
  final IconData icon;
  final Color color;
  const _Mode(this.label, this.icon, this.color);
}
