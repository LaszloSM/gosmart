import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_skeleton_loader.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Mis Viajes'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildPillTabBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: GSBottomNav(
        currentIndex: 1,
        onTap: _onNavTap,
      ),
    );
  }

  void _onNavTap(int i) {
    switch (i) {
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

  Widget _buildPillTabBar() {
    return Padding(
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          _tabPill('Viajes', 0),
          const SizedBox(width: GSSpacing.s2),
          _tabPill('Tickets', 1),
          const SizedBox(width: GSSpacing.s2),
          _tabPill('Recibos', 2),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: GSDuration.normal,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? GSColors.accent : GSColors.surfaceDark,
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : GSColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 1:
        return const GSEmptyState(
          icon: Icons.confirmation_number_rounded,
          title: 'Sin tickets',
          subtitle: 'Tus tickets de transporte aparecerán aquí',
        );
      case 2:
        return const GSEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Sin recibos',
          subtitle: 'Los recibos detallados de cada viaje se guardan aquí',
        );
      default:
        return _buildViajasTab();
    }
  }

  Widget _buildViajasTab() {
    final txState = ref.watch(transactionListProvider);

    return txState.when(
      loading: () => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        child: Column(
          children: [
            const GSSkeletonLoader(
              width: double.infinity,
              height: 72,
              radius: 20,
            ),
            const SizedBox(height: GSSpacing.s4),
            ...List.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: GSSpacing.s2),
                child: GSTransactionSkeleton(),
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(GSSpacing.s4),
        child: GSErrorCard(
          message: error.toString(),
          onRetry: () =>
              ref.read(transactionListProvider.notifier).load(refresh: true),
        ),
      ),
      data: (list) {
        final now = DateTime.now();
        final thisMonth = list
            .where(
              (t) =>
                  t.createdAt.year == now.year &&
                  t.createdAt.month == now.month,
            )
            .toList();
        final totalSpent =
            thisMonth.fold<double>(0, (s, t) => s + t.amount);
        final totalTrips = thisMonth.length;

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
              ref.read(transactionListProvider.notifier).loadMore();
            }
            return false;
          },
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            child: Column(
              children: [
                // Monthly summary card
                GSCard(
                  padding: const EdgeInsets.all(GSSpacing.s4),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total este mes',
                            style: TextStyle(
                              fontSize: 13,
                              color: GSColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCOP(totalSpent),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: GSColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalTrips.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: GSColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'viajes',
                            style: TextStyle(
                              fontSize: 13,
                              color: GSColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GSSpacing.s4),
                // Trip list or empty state
                if (list.isEmpty)
                  GSEmptyState(
                    icon: Icons.directions_bus_rounded,
                    title: 'No tienes viajes aún',
                    subtitle: 'Empieza tu primer viaje',
                    actionLabel: 'Planificar viaje',
                    onAction: () => context.go(AppRoutes.routePlanner),
                  )
                else
                  Column(
                    children: [
                      ...list.map(
                        (t) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: GSSpacing.s2),
                          child: _buildTripCard(t),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: GSSpacing.s2),
                        child: TextButton(
                          onPressed: () => ref
                              .read(transactionListProvider.notifier)
                              .loadMore(),
                          child: const Text(
                            'Cargar más →',
                            style: TextStyle(
                              color: GSColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: GSSpacing.s4),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTripCard(TransactionModel t) {
    final modeColor = _modeColor(t.mode);
    final modeIcon = _modeIcon(t.mode);
    final status = t.status;
    final statusColor = status == 'completed'
        ? GSColors.success
        : status == 'failed'
            ? GSColors.error
            : GSColors.warning;
    final statusLabel = status == 'completed'
        ? 'Completado'
        : status == 'failed'
            ? 'Fallido'
            : 'Pendiente';
    final statusBg = status == 'completed'
        ? GSColors.successLight
        : status == 'failed'
            ? GSColors.errorLight
            : GSColors.warningLight;

    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: modeColor.withValues(alpha: 0.15),
            child: Icon(modeIcon, color: modeColor, size: 20),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.destination ?? t.origin ?? _typeLabel(t.type),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GSColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(t.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: GSColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCOP(t.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GSColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s2, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

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

  String _typeLabel(String type) {
    switch (type) {
      case 'trip':
        return 'Viaje';
      case 'recharge':
        return 'Recarga';
      case 'refund':
        return 'Reembolso';
      default:
        return 'Movimiento';
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

  String _formatCOP(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '\$$formatted COP';
  }
}
