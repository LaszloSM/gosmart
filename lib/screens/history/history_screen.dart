import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_card.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/transaction_model.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Trips & Receipts'),
        leading: const BackButton(),
        bottom: TabBar(
          controller: _tab,
          labelColor: GSColors.primary,
          unselectedLabelColor: GSColors.textSecondary,
          indicatorColor: GSColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Trips'),
            Tab(text: 'Tickets'),
            Tab(text: 'Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TripsTab(ref: ref),
          const _EmptyState(
            icon: Icons.confirmation_number_rounded,
            title: 'No active tickets',
            body: 'Your purchased tickets will appear here.',
          ),
          const _EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No receipts yet',
            body: 'Detailed receipts for every trip are saved here.',
          ),
        ],
      ),
    );
  }
}

// ─── Trips tab ────────────────────────────────────────────────────────────────

class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionListProvider);
    final ecoPoints = ref.watch(profileProvider).valueOrNull?.formattedEcoPoints ?? '0';

    return txState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: GSColors.error),
            const SizedBox(height: 12),
            Text('Error loading trips',
                style: TextStyle(color: GSColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(transactionListProvider.notifier).load(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (transactions) {
        final trips =
            transactions.where((t) => t.isTrip).toList();

        // Monthly summary
        final now = DateTime.now();
        final monthTrips = trips
            .where((t) =>
                t.createdAt.year == now.year &&
                t.createdAt.month == now.month)
            .toList();
        final monthSpend =
            monthTrips.fold<double>(0, (sum, t) => sum + t.amount);
        final monthCo2 = monthTrips.fold<double>(
            0, (sum, t) => sum + (t.co2Kg ?? 0));

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
              ref.read(transactionListProvider.notifier).loadMore();
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.all(GSSpacing.s5),
            children: [
              // Monthly summary
              GSCard(
                padding: const EdgeInsets.all(GSSpacing.s5),
                shadow: GSShadow.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This month',
                        style: TextStyle(
                            fontSize: 13, color: GSColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(monthSpend),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: GSColors.textPrimary),
                    ),
                    const SizedBox(height: GSSpacing.s4),
                    Row(
                      children: [
                        _MiniStat(
                            icon: Icons.directions_bus_rounded,
                            label: '${monthTrips.length} trips',
                            color: GSColors.bus),
                        const SizedBox(width: GSSpacing.s4),
                        _MiniStat(
                            icon: Icons.eco_rounded,
                            label: '${monthCo2.toStringAsFixed(1)} kg CO₂',
                            color: GSColors.eco),
                        const SizedBox(width: GSSpacing.s4),
                        _MiniStat(
                            icon: Icons.star_rounded,
                            label: '$ecoPoints pts',
                            color: GSColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GSSpacing.s5),

              Text('Recent trips',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: GSSpacing.s3),

              if (trips.isEmpty)
                const _EmptyState(
                  icon: Icons.directions_bus_rounded,
                  title: 'No trips yet',
                  body: 'Your travel history will appear here after your first trip.',
                )
              else
                ...trips.map((t) => _TripTile(tx: t)),
            ],
          ),
        );
      },
    );
  }

  static String _formatAmount(double amount) {
    return NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    ).format(amount);
  }
}

// ─── Trip tile ────────────────────────────────────────────────────────────────

class _TripTile extends StatelessWidget {
  const _TripTile({required this.tx});
  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final failed = tx.status == 'failed';
    final modeIcon = _modeIcon(tx.mode);
    final modeColor = _modeColor(tx.mode);
    final originLabel = tx.origin ?? tx.type;
    final destLabel = tx.destination ?? '—';

    return GSCard(
      margin: const EdgeInsets.only(bottom: GSSpacing.s3),
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(GSRadius.md),
            ),
            child: Icon(modeIcon, color: modeColor, size: 22),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(originLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: GSColors.textPrimary)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: GSColors.textDisabled),
                    ),
                    Flexible(
                      child: Text(destLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: GSColors.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_relativeDate(tx.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                    if (!failed && tx.co2Kg != null) ...[
                      const SizedBox(width: GSSpacing.s3),
                      const Icon(Icons.eco_rounded,
                          size: 12, color: GSColors.eco),
                      const SizedBox(width: 2),
                      Text('${tx.co2Kg!.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                              fontSize: 11, color: GSColors.eco)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                failed
                    ? 'Failed'
                    : NumberFormat.currency(
                        locale: 'es_CO',
                        symbol: '\$',
                        decimalDigits: 0,
                      ).format(tx.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: failed ? GSColors.error : GSColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: failed ? GSColors.errorLight : GSColors.successLight,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
                child: Text(
                  failed ? 'Failed' : 'Done',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: failed ? GSColors.error : GSColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    final time = DateFormat.jm().format(dt);
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    return '${DateFormat('MMM d').format(dt)}, $time';
  }

  static IconData _modeIcon(String? mode) {
    switch (mode) {
      case 'metro':
        return Icons.subway_rounded;
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'bike':
        return Icons.pedal_bike_rounded;
      case 'walk':
        return Icons.directions_walk_rounded;
      default:
        return Icons.directions_bus_rounded;
    }
  }

  static Color _modeColor(String? mode) {
    switch (mode) {
      case 'metro':
        return GSColors.metro;
      case 'taxi':
        return GSColors.taxi;
      case 'bike':
        return GSColors.bike;
      default:
        return GSColors.bus;
    }
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSSpacing.s10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: GSColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: GSColors.textDisabled),
            ),
            const SizedBox(height: GSSpacing.s5),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: GSColors.textPrimary)),
            const SizedBox(height: GSSpacing.s2),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: GSColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
