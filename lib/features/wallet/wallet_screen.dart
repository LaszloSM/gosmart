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
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
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

  // ── Recharge sheet ──────────────────────────────────────────────────────────
  void _showRechargeSheet() {
    GSBottomSheet.show(
      context: context,
      title: 'Recargar tarjeta',
      initialChildSize: 0.55,
      child: _RechargeSheetContent(
        onConfirm: (amount) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recarga de \$${amount.toStringAsFixed(0)} COP próximamente'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
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
      extendBody: true,
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
      loading: () => const GSCardSkeleton(height: 200),
      error: (e, _) => GSErrorCard(
        message: 'No se pudo cargar la tarjeta',
        onRetry: () => ref.read(activeCardProvider.notifier).refresh(),
      ),
      data: (card) {
        final isLocked = card?.isLocked ?? false;
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s4,
            vertical: GSSpacing.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GSRadius.xl),
            boxShadow: [
              BoxShadow(
                color: GSColors.accentAlt.withValues(alpha: 0.24),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GSRadius.xl),
            child: Stack(
              children: [
                // Layer 1: card content
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLocked
                          ? const [Color(0xFF1A1F2F), Color(0xFF252B3F)]
                          : [GSColors.primary, GSColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(GSRadius.xl),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top row
                      Row(
                        children: [
                          const _ChipWidget(),
                          const SizedBox(width: 10),
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
                                borderRadius:
                                    BorderRadius.circular(GSRadius.full),
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
                            Text(
                              'GoSmart',
                              style: TextStyle(
                                color: GSColors.primary.withValues(alpha: 0.85),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                        ],
                      ),

                      // Card number
                      Text(
                        card?.numberMasked ?? '•••• •••• •••• 0000',
                        style: TextStyle(
                          color: GSColors.primary.withValues(alpha: 0.75),
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
                              Text(
                                'Saldo disponible',
                                style: TextStyle(
                                  color: GSColors.primary.withValues(alpha: 0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              _AnimatedBalance(
                                key: ValueKey(card?.balance),
                                amount: card?.balance ?? 0,
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
                              color:
                                  isLocked ? GSColors.error : GSColors.success,
                              borderRadius:
                                  BorderRadius.circular(GSRadius.full),
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
                ),

                // Layer 2: gloss overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: GSGradient.cardGloss,
                        stops: const [0.0, 0.6],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section 2 ───────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final card = ref.watch(activeCardProvider).valueOrNull;
    final isLocked = card?.isLocked ?? false;

    final actions = [
      _QuickAction(
        icon: Icons.add_circle_outline_rounded,
        label: 'Recargar',
        color: GSColors.accent,
        onTap: _showRechargeSheet,
      ),
      _QuickAction(
        icon: Icons.qr_code_rounded,
        label: 'Pagar',
        color: GSColors.accentAlt,
        onTap: () => context.push(AppRoutes.paymentValidation),
      ),
      _QuickAction(
        icon: isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
        label: isLocked ? 'Desbloquear' : 'Bloquear',
        color: isLocked ? GSColors.success : GSColors.error,
        onTap: _toggleLock,
      ),
    ];

    return GSCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(
            actions.length * 2 - 1,
            (i) {
              if (i.isOdd) {
                return const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 12,
                  endIndent: 12,
                );
              }
              final action = actions[i ~/ 2];
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: action.onTap,
                    splashColor: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(GSRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: GSSpacing.s4,
                        horizontal: GSSpacing.s2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: action.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              action.icon,
                              color: action.color,
                              size: GSSize.iconLg,
                            ),
                          ),
                          const SizedBox(height: GSSpacing.s1),
                          Text(
                            action.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: GSColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
          loading: () => StaggeredSkeletonList(
            itemCount: 5,
            itemBuilder: (_) => const GSTransactionSkeleton(),
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

// ─── Quick Action data class ──────────────────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ─── Recharge sheet content ───────────────────────────────────────────────────

class _RechargeSheetContent extends StatefulWidget {
  const _RechargeSheetContent({required this.onConfirm});
  final ValueChanged<double> onConfirm;

  @override
  State<_RechargeSheetContent> createState() => _RechargeSheetContentState();
}

class _RechargeSheetContentState extends State<_RechargeSheetContent> {
  double _selected = 10000;

  static const _amounts = [5000.0, 10000.0, 20000.0, 50000.0, 100000.0];

  String _fmt(double v) {
    final s = v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '\$$s COP';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecciona un monto',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: GSColors.textSecondary)),
        const SizedBox(height: GSSpacing.s4),
        Wrap(
          spacing: GSSpacing.s2,
          runSpacing: GSSpacing.s2,
          children: _amounts.map((a) {
            final isSelected = _selected == a;
            return GestureDetector(
              onTap: () => setState(() => _selected = a),
              child: AnimatedContainer(
                duration: GSDuration.normal,
                padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
                decoration: BoxDecoration(
                  color: isSelected ? GSColors.accent : GSColors.surfaceDark,
                  borderRadius: BorderRadius.circular(GSRadius.lg),
                  border: Border.all(
                    color: isSelected ? GSColors.accent : GSColors.border,
                  ),
                ),
                child: Text(
                  _fmt(a),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : GSColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: GSSpacing.s6),
        GSButton(
          label: 'Continuar con ${_fmt(_selected)}',
          onPressed: () => widget.onConfirm(_selected),
          leadingIcon: Icons.add_rounded,
        ),
        const SizedBox(height: GSSpacing.s3),
        const Text(
          'Integración con Stripe disponible próximamente',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: GSColors.textDisabled),
        ),
      ],
    );
  }
}

// ─── Chip widget ──────────────────────────────────────────────────────────────

/// Decorative chip on the wallet card.
class _ChipWidget extends StatelessWidget {
  const _ChipWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GSRadius.sm),
        border: Border.all(color: GSColors.cardGold, width: 1),
        gradient: LinearGradient(
          colors: [
            GSColors.cardGold.withValues(alpha: 0.6),
            GSColors.cardGold.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// ─── Animated balance ─────────────────────────────────────────────────────────

/// Balance with count-up animation from 0 to [amount].
class _AnimatedBalance extends StatelessWidget {
  const _AnimatedBalance({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount),
      duration: GSAnimDuration.countUp,
      curve: Curves.easeOut,
      builder: (_, value, __) => Text(
        '\$${value.toStringAsFixed(0)} COP',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: GSColors.primary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
