import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _filter = 'All';

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

  static const _trips = [
    _Trip(
      origin: 'PITX',
      destination: 'Cubao',
      date: 'Today, 9:30 AM',
      amount: '\$2.80',
      mode: 'Bus',
      modeIcon: Icons.directions_bus_rounded,
      modeColor: GSColors.bus,
      status: 'completed',
      co2: '0.3 kg',
    ),
    _Trip(
      origin: 'Makati CBD',
      destination: 'BGC',
      date: 'Yesterday, 6:15 PM',
      amount: '\$1.50',
      mode: 'Metro',
      modeIcon: Icons.subway_rounded,
      modeColor: GSColors.metro,
      status: 'completed',
      co2: '0.1 kg',
    ),
    _Trip(
      origin: 'Ortigas',
      destination: 'Mandaluyong',
      date: 'Mar 11, 2:00 PM',
      amount: '\$0.80',
      mode: 'Bike',
      modeIcon: Icons.pedal_bike_rounded,
      modeColor: GSColors.bike,
      status: 'completed',
      co2: '0 kg',
    ),
    _Trip(
      origin: 'Airport T3',
      destination: 'Makati',
      date: 'Mar 10, 8:45 AM',
      amount: '\$18.00',
      mode: 'Taxi',
      modeIcon: Icons.local_taxi_rounded,
      modeColor: GSColors.taxi,
      status: 'completed',
      co2: '2.1 kg',
    ),
    _Trip(
      origin: 'SM North',
      destination: 'Quezon Ave',
      date: 'Mar 9, 11:30 AM',
      amount: '\$1.20',
      mode: 'Bus',
      modeIcon: Icons.directions_bus_rounded,
      modeColor: GSColors.bus,
      status: 'failed',
      co2: '—',
    ),
  ];

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
          // Trips tab
          _TripsTab(trips: _trips),

          // Tickets tab (placeholder)
          const _EmptyState(
            icon: Icons.confirmation_number_rounded,
            title: 'No active tickets',
            body: 'Your purchased tickets will appear here.',
          ),

          // Receipts tab (placeholder)
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

class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.trips});
  final List<_Trip> trips;

  @override
  Widget build(BuildContext context) {
    // Monthly spend summary card
    return ListView(
      padding: const EdgeInsets.all(GSSpacing.s5),
      children: [
        // Summary
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
              const Text('\$24.30',
                  style: TextStyle(
                      
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: GSColors.textPrimary)),
              const SizedBox(height: GSSpacing.s4),
              Row(
                children: [
                  _MiniStat(
                      icon: Icons.directions_bus_rounded,
                      label: '8 trips',
                      color: GSColors.bus),
                  const SizedBox(width: GSSpacing.s4),
                  _MiniStat(
                      icon: Icons.eco_rounded,
                      label: '1.2 kg CO₂ saved',
                      color: GSColors.eco),
                  const SizedBox(width: GSSpacing.s4),
                  _MiniStat(
                      icon: Icons.star_rounded,
                      label: '240 pts',
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

        ...trips.map((t) => _TripTile(trip: t)),
      ],
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});
  final _Trip trip;

  @override
  Widget build(BuildContext context) {
    final failed = trip.status == 'failed';
    return GSCard(
      margin: const EdgeInsets.only(bottom: GSSpacing.s3),
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: trip.modeColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(GSRadius.md),
            ),
            child: Icon(trip.modeIcon, color: trip.modeColor, size: 22),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(trip.origin,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: GSColors.textPrimary)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: GSColors.textDisabled),
                    ),
                    Text(trip.destination,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: GSColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(trip.date,
                        style: const TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                    const SizedBox(width: GSSpacing.s3),
                    if (!failed)
                      Row(
                        children: [
                          const Icon(Icons.eco_rounded,
                              size: 12, color: GSColors.eco),
                          const SizedBox(width: 2),
                          Text(trip.co2,
                              style: const TextStyle(
                                  fontSize: 11, color: GSColors.eco)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                failed ? 'Failed' : trip.amount,
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
}

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
            style: TextStyle(fontSize: 11, color: color,
                fontWeight: FontWeight.w500)),
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

class _Trip {
  final String origin;
  final String destination;
  final String date;
  final String amount;
  final String mode;
  final IconData modeIcon;
  final Color modeColor;
  final String status;
  final String co2;
  const _Trip({
    required this.origin,
    required this.destination,
    required this.date,
    required this.amount,
    required this.mode,
    required this.modeIcon,
    required this.modeColor,
    required this.status,
    required this.co2,
  });
}
