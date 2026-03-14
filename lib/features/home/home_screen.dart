import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          Positioned.fill(
            child: _MockMap(),
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
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: GSColors.accentLight,
                        child: Icon(
                          Icons.person_rounded,
                          color: GSColors.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola 👋',
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

// ─── Mock Map ─────────────────────────────────────────────────────────────────

class _MockMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEF4),
      child: CustomPaint(
        painter: _MapPainter(),
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              left: MediaQuery.of(context).size.width * 0.42,
              child: _LocationMarker(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationMarker extends StatefulWidget {
  @override
  State<_LocationMarker> createState() => _LocationMarkerState();
}

class _LocationMarkerState extends State<_LocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulse = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: _pulse,
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
              boxShadow: GSShadow.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Road paint
    final roadPaint = Paint()
      ..color = const Color(0xFFD0DAE8)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Main horizontal road
    roadPaint.strokeWidth = 14;
    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.35),
      roadPaint,
    );

    // Main vertical road
    roadPaint.strokeWidth = 20;
    canvas.drawLine(
      Offset(size.width * 0.30, 0),
      Offset(size.width * 0.35, size.height),
      roadPaint,
    );

    // Secondary road
    roadPaint.strokeWidth = 8;
    canvas.drawLine(
      Offset(0, size.height * 0.60),
      Offset(size.width * 0.60, size.height * 0.50),
      roadPaint,
    );

    // Diagonal road
    roadPaint.strokeWidth = 6;
    canvas.drawLine(
      Offset(size.width * 0.60, 0),
      Offset(size.width, size.height * 0.45),
      roadPaint,
    );

    // Small cross street
    roadPaint.strokeWidth = 6;
    canvas.drawLine(
      Offset(0, size.height * 0.15),
      Offset(size.width * 0.28, size.height * 0.15),
      roadPaint,
    );

    // City blocks
    final blockPaint = Paint()
      ..color = const Color(0xFFDDE5EE)
      ..style = PaintingStyle.fill;

    final blocks = [
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.05,
        size.width * 0.22,
        size.height * 0.20,
      ),
      Rect.fromLTWH(
        size.width * 0.40,
        size.height * 0.05,
        size.width * 0.18,
        size.height * 0.22,
      ),
      Rect.fromLTWH(
        size.width * 0.65,
        size.height * 0.08,
        size.width * 0.28,
        size.height * 0.18,
      ),
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.42,
        size.width * 0.20,
        size.height * 0.25,
      ),
      Rect.fromLTWH(
        size.width * 0.42,
        size.height * 0.45,
        size.width * 0.50,
        size.height * 0.30,
      ),
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.72,
        size.width * 0.22,
        size.height * 0.22,
      ),
      Rect.fromLTWH(
        size.width * 0.65,
        size.height * 0.30,
        size.width * 0.15,
        size.height * 0.12,
      ),
    ];

    for (final r in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        blockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _Mode {
  final String label;
  final IconData icon;
  final Color color;
  const _Mode(this.label, this.icon, this.color);
}
