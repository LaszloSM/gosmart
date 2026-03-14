import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../router/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/card_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  String _selectedMode = 'Car';
  bool _showNotification = true;

  static const _modes = [
    _Mode('Car', Icons.directions_car_rounded, GSColors.car),
    _Mode('Taxi', Icons.local_taxi_rounded, GSColors.taxi),
    _Mode('Bus', Icons.directions_bus_rounded, GSColors.bus),
    _Mode('Bike', Icons.pedal_bike_rounded, GSColors.bike),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      body: Stack(
        children: [
          // ── Map layer (mock) ──────────────────────────────────────────────
          Positioned.fill(
            child: _MockMap(),
          ),

          // ── Notification banner ──────────────────────────────────────────
          if (_showNotification)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: GSNotificationBanner(
                title: 'Route update',
                body: 'Your route changes due to congestion on Line 3',
                icon: Icons.warning_amber_rounded,
                onDismiss: () => setState(() => _showNotification = false),
                onTap: () => context.push(AppRoutes.routePlanner),
              ),
            ),

          // ── Bottom panel ─────────────────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            builder: (_, ctrl) {
              return Container(
                decoration: BoxDecoration(
                  color: GSColors.bg,
                  borderRadius: GSRadius.sheetRadius,
                  boxShadow: GSShadow.lg,
                ),
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSSpacing.s5, vertical: GSSpacing.s3),
                  children: [
                    // drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: GSSpacing.s4),
                        decoration: BoxDecoration(
                          color: GSColors.border,
                          borderRadius: BorderRadius.circular(GSRadius.full),
                        ),
                      ),
                    ),

                    // Header
                    _HomeHeader(
                      name: ref.watch(profileProvider).valueOrNull?.name ?? '',
                    ),
                    const SizedBox(height: GSSpacing.s4),

                    // Search
                    GSSearchBar(
                      hint: 'Enter destination',
                      readOnly: true,
                      onTap: () =>
                          context.push(AppRoutes.routePlanner),
                      trailing: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GSColors.primary,
                          borderRadius: BorderRadius.circular(GSRadius.sm),
                        ),
                        child: const Icon(Icons.map_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: GSSpacing.s4),

                    // Mode selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _modes
                          .map((m) => GSModeChip(
                                label: m.label,
                                icon: m.icon,
                                color: m.color,
                                isSelected: _selectedMode == m.label,
                                onTap: () =>
                                    setState(() => _selectedMode = m.label),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: GSSpacing.s5),

                    // From / To
                    _LocationRow(),
                    const SizedBox(height: GSSpacing.s4),

                    // Date + Passengers
                    Row(
                      children: [
                        Expanded(
                          child: _FieldTile(
                            label: 'Departing on',
                            value: 'Select Date',
                            icon: Icons.calendar_today_rounded,
                          ),
                        ),
                        const SizedBox(width: GSSpacing.s3),
                        Expanded(
                          child: _FieldTile(
                            label: 'Passengers',
                            value: '1 Passenger',
                            icon: Icons.people_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GSSpacing.s5),

                    // Search button
                    GSButton(
                      label: 'Search',
                      onPressed: () =>
                          context.push(AppRoutes.routeDetail),
                      leadingIcon: Icons.search_rounded,
                    ),
                    const SizedBox(height: GSSpacing.s5),

                    // Cards row
                    Text('Quick stats',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: GSSpacing.s3),
                    Row(
                      children: [
                        Expanded(
                          child: GSInfoCard(
                            title: 'Balance',
                            value: ref.watch(activeCardProvider).valueOrNull
                                    ?.formattedBalance ??
                                '—',
                            icon: Icons.account_balance_wallet_rounded,
                            iconBgColor: GSColors.primary,
                            subtitle: 'Top up credit',
                            onTap: () => context.push(AppRoutes.wallet),
                          ),
                        ),
                        const SizedBox(width: GSSpacing.s3),
                        Expanded(
                          child: GSInfoCard(
                            title: 'Eco Points',
                            value: ref
                                    .watch(profileProvider)
                                    .valueOrNull
                                    ?.formattedEcoPoints ??
                                '0',
                            icon: Icons.eco_rounded,
                            iconBgColor: GSColors.eco,
                            subtitle: 'CO₂ saved',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GSSpacing.s5),

                    // AI quick access
                    GSCard(
                      onTap: () => context.push(AppRoutes.aiChat),
                      padding: const EdgeInsets.all(GSSpacing.s4),
                      shadow: GSShadow.primary,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: GSColors.accentLight,
                              borderRadius: BorderRadius.circular(GSRadius.md),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: GSColors.primary, size: 24),
                          ),
                          const SizedBox(width: GSSpacing.s3),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ask GoSmart AI',
                                    style: TextStyle(
                                        
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: GSColors.textPrimary)),
                                Text('Plan a route in natural language',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: GSColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: GSColors.textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: GSSpacing.s10),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: GSBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          switch (i) {
            case 1:
              context.push(AppRoutes.history);
              break;
            case 2:
              context.push(AppRoutes.wallet);
              break;
            case 3:
              context.push(AppRoutes.profile);
              break;
          }
        },
      ),
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? 'there' : name.split(' ').first;
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: GSColors.accentLight,
          child: Icon(Icons.person_rounded, color: GSColors.primary),
        ),
        const SizedBox(width: GSSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: 'Hello ',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: GSColors.textPrimary),
                  children: [
                    TextSpan(
                      text: '$displayName,',
                      style: const TextStyle(color: GSColors.primary),
                    ),
                  ],
                ),
              ),
              const Text('Where to go?',
                  style: TextStyle(
                      
                      fontSize: 14,
                      color: GSColors.textSecondary)),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: GSColors.surface,
            shape: BoxShape.circle,
            boxShadow: GSShadow.sm,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_rounded,
                  color: GSColors.textSecondary, size: 22),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: GSColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Column(
        children: [
          _LocField(
              label: 'From',
              value: 'PITX\nParañaque City',
              icon: Icons.radio_button_checked_rounded,
              iconColor: GSColors.primary),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(height: 1, color: GSColors.border),
          ),
          _LocField(
            label: 'To',
            value: 'Cubao\nQuezon City',
            icon: Icons.location_on_rounded,
            iconColor: GSColors.error,
            trailing: const Icon(Icons.edit_rounded,
                size: 16, color: GSColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

class _LocField extends StatelessWidget {
  const _LocField({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.trailing,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: GSColors.textDisabled)),
                Text(value.split('\n')[0],
                    style: const TextStyle(
                        
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: GSColors.textPrimary)),
                Text(value.split('\n')[1],
                    style: const TextStyle(
                        fontSize: 11, color: GSColors.textSecondary)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: GSColors.primary),
          const SizedBox(width: GSSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: GSColors.textDisabled)),
                Text(value,
                    style: const TextStyle(
                        
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: GSColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEF4),
      child: CustomPaint(
        painter: _MapPainter(),
        child: Stack(
          children: [
            // Moving location marker (mock)
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
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
                color: GSColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: GSColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: GSShadow.primary,
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
    final paint = Paint()
      ..color = const Color(0xFFD0DAE8)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw mock roads
    final roads = [
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.35),
    ];
    canvas.drawLine(roads[0], roads[1], paint);

    paint.strokeWidth = 20;
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.35, size.height),
      paint,
    );

    paint.strokeWidth = 8;
    canvas.drawLine(
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.5),
      paint,
    );

    // Grid blocks
    final blockPaint = Paint()
      ..color = const Color(0xFFDDE5EE)
      ..style = PaintingStyle.fill;

    final blocks = [
      Rect.fromLTWH(size.width * 0.05, size.height * 0.05,
          size.width * 0.22, size.height * 0.2),
      Rect.fromLTWH(size.width * 0.4, size.height * 0.05,
          size.width * 0.18, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.65, size.height * 0.08,
          size.width * 0.28, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.05, size.height * 0.42,
          size.width * 0.2, size.height * 0.25),
      Rect.fromLTWH(size.width * 0.42, size.height * 0.45,
          size.width * 0.5, size.height * 0.3),
    ];

    for (final r in blocks) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), blockPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Mode {
  final String label;
  final IconData icon;
  final Color color;
  const _Mode(this.label, this.icon, this.color);
}
