// lib/features/wallet/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/transaction_model.dart';
import '../../providers/card_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_skeleton_loader.dart';
import '../../widgets/gs_toast.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  // ── Navigation ──────────────────────────────────────────────────────────────
  void _onNavTap(int i) {
    switch (i) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.history);
      case 2:
        context.go(AppRoutes.wallet);
      case 3:
        context.go(AppRoutes.profile);
    }
  }

  // ── Card lock toggle ────────────────────────────────────────────────────────
  Future<void> _toggleLock() async {
    final card = ref.read(activeCardProvider).valueOrNull;
    if (card == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final newLocked = !card.isLocked;
    try {
      await ref.read(activeCardProvider.notifier).toggleLock(card.id, newLocked);
      GSToast.showWithMessenger(
        messenger,
        message: newLocked ? 'Tarjeta bloqueada' : 'Tarjeta desbloqueada',
        type: newLocked ? GSToastType.warning : GSToastType.success,
      );
    } catch (e) {
      GSToast.showWithMessenger(
        messenger,
        message: 'Error al cambiar estado',
        type: GSToastType.error,
      );
    }
  }

  // ── Recharge snackbar ───────────────────────────────────────────────────────
  void _showRechargeSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de recarga próximamente'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Mode helpers ────────────────────────────────────────────────────────────
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

  String _formatAmount(TransactionModel t) {
    final amt = t.amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '\$$amt COP';
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mi Billetera'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: GSSpacing.s4),

            // ── Section 1: Physical card ──────────────────────────────────────
            _buildCardSection(),
            const SizedBox(height: GSSpacing.s4),

            // ── Section 2: Quick actions ──────────────────────────────────────
            _buildQuickActions(),
            const SizedBox(height: GSSpacing.s4),

            // ── Section 3: Recent transactions ───────────────────────────────
            _buildRecentTransactions(theme),
            const SizedBox(height: GSSpacing.s4),

            // ── Section 4: Card controls ──────────────────────────────────────
            _buildCardControls(theme),
            const SizedBox(height: GSSpacing.s6),
          ],
        ),
      ),
      bottomNavigationBar: GSBottomNav(
        currentIndex: 2,
        onTap: _onNavTap,
      ),
    );
  }

  // ── Section 1 ───────────────────────────────────────────────────────────────
  Widget _buildCardSection() {
    return ref.watch(activeCardProvider).when(
      loading: () => const GSSkeletonLoader(
        width: double.infinity,
        height: 200,
        radius: 20,
      ),
      error: (e, _) => GSErrorCard(
        message: 'No se pudo cargar la tarjeta',
        onRetry: () => ref.read(activeCardProvider.notifier).refresh(),
      ),
      data: (card) {
        final isLocked = card?.isLocked ?? false;
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLocked
                  ? const [Color(0xFF6B7280), Color(0xFF374151)]
                  : const [Color(0xFF1A1A2E), Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isLocked
                ? [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x406C63FF),
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row
              Row(
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    color: Color(0xFFFFD700),
                    size: 32,
                  ),
                  const Spacer(),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GSColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(GSRadius.full),
                        border: Border.all(color: GSColors.error),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'BLOQUEADA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'GoSmart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),

              // Card number
              Text(
                card?.numberMasked ?? '•••• •••• •••• 0000',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Bottom row — balance + status badge
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo disponible',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        card?.formattedBalance ?? '\$0 COP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isLocked ? GSColors.error : GSColors.success,
                      borderRadius: BorderRadius.circular(GSRadius.full),
                    ),
                    child: Text(
                      isLocked ? 'Bloqueada' : 'Activa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Section 2 ───────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Row(
      children: [
        _QuickAction(
          icon: Icons.add_circle_rounded,
          label: 'Recargar',
          color: GSColors.accent,
          onTap: _showRechargeSnackbar,
        ),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Pagar',
          color: GSColors.accentAlt,
          onTap: () => context.push(AppRoutes.paymentValidation),
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final card = ref.watch(activeCardProvider).valueOrNull;
            return _QuickAction(
              icon: card?.isLocked ?? false
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
              label: card?.isLocked ?? false ? 'Desbloquear' : 'Bloquear',
              color: card?.isLocked ?? false ? GSColors.success : GSColors.error,
              onTap: _toggleLock,
            );
          },
        ),
      ],
    );
  }

  // ── Section 3 ───────────────────────────────────────────────────────────────
  Widget _buildRecentTransactions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Movimientos recientes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.history),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ref.watch(transactionListProvider).when(
          loading: () => Column(
            children: List.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: GSTransactionSkeleton(),
              ),
            ),
          ),
          error: (e, _) => GSErrorCard(
            message: e.toString(),
            onRetry: () => ref
                .read(transactionListProvider.notifier)
                .load(refresh: true),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const GSEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Sin movimientos',
                subtitle: 'Tus transacciones aparecerán aquí',
              );
            }
            return Column(
              children: list
                  .take(5)
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              _modeColor(t.mode).withValues(alpha: 0.15),
                          child: Icon(
                            _modeIcon(t.mode),
                            color: _modeColor(t.mode),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          t.destination ?? t.origin ?? _typeLabel(t.type),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          _formatDate(t.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: GSColors.textSecondary,
                              ),
                        ),
                        trailing: Text(
                          _formatAmount(t),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Section 4 ───────────────────────────────────────────────────────────────
  Widget _buildCardControls(ThemeData theme) {
    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Controles de tarjeta',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          ref.watch(activeCardProvider).when(
            data: (card) => Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bloquear tarjeta'),
                  subtitle:
                      const Text('Desactiva temporalmente la tarjeta'),
                  secondary: Icon(
                    Icons.lock_rounded,
                    color: card?.isLocked ?? false
                        ? GSColors.error
                        : GSColors.textSecondary,
                  ),
                  value: card?.isLocked ?? false,
                  activeThumbColor: GSColors.error,
                  onChanged: (_) => _toggleLock(),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.report_problem_rounded,
                    color: GSColors.error,
                  ),
                  title: const Text('Reportar pérdida'),
                  subtitle:
                      const Text('Bloquea y solicita nueva tarjeta'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: GSColors.textDisabled,
                  ),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contacta con soporte al cliente'),
                    ),
                  ),
                ),
              ],
            ),
            loading: () => const GSSkeletonLoader(
              width: double.infinity,
              height: 100,
              radius: 12,
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action tile ────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.xl),
            boxShadow: GSShadow.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: GSColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
