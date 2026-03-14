import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_text_field.dart';
import '../../router/app_router.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _originCtrl = TextEditingController(text: 'PITX, Parañaque City');
  final _destCtrl = TextEditingController(text: 'Cubao, Quezon City');
  String _selected = 'fastest';
  bool _isLoading = false;

  static const _options = [
    _RouteOption(
      id: 'fastest',
      label: 'Fastest',
      icon: Icons.bolt_rounded,
      iconColor: GSColors.primary,
      time: '42 min',
      cost: '\$2.80',
      co2: '0.3 kg',
      steps: [
        _Step('Walk', '5 min', Icons.directions_walk_rounded, GSColors.walk),
        _Step('Bus 22', '20 min', Icons.directions_bus_rounded, GSColors.bus),
        _Step('Metro L3', '12 min', Icons.subway_rounded, GSColors.metro),
        _Step('Walk', '5 min', Icons.directions_walk_rounded, GSColors.walk),
      ],
    ),
    _RouteOption(
      id: 'cheapest',
      label: 'Cheapest',
      icon: Icons.savings_rounded,
      iconColor: GSColors.warning,
      time: '58 min',
      cost: '\$1.20',
      co2: '0.4 kg',
      steps: [
        _Step('Walk', '5 min', Icons.directions_walk_rounded, GSColors.walk),
        _Step('Bus 14', '35 min', Icons.directions_bus_rounded, GSColors.bus),
        _Step('Walk', '18 min', Icons.directions_walk_rounded, GSColors.walk),
      ],
    ),
    _RouteOption(
      id: 'eco',
      label: 'Eco',
      icon: Icons.eco_rounded,
      iconColor: GSColors.eco,
      time: '55 min',
      cost: '\$1.80',
      co2: '0.05 kg',
      steps: [
        _Step('Bike', '10 min', Icons.pedal_bike_rounded, GSColors.bike),
        _Step('Metro L2', '30 min', Icons.subway_rounded, GSColors.metro),
        _Step('Walk', '15 min', Icons.directions_walk_rounded, GSColors.walk),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Plan Route'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Ask AI',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.aiChat),
          ),
        ],
      ),
      body: Column(
        children: [
          // Origin / Destination inputs
          _LocationInputs(originCtrl: _originCtrl, destCtrl: _destCtrl),

          // Route alternatives
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(GSSpacing.s5),
              itemCount: _options.length,
              separatorBuilder: (_, __) => const SizedBox(height: GSSpacing.s3),
              itemBuilder: (_, i) {
                final opt = _options[i];
                return _RouteCard(
                  option: opt,
                  isSelected: _selected == opt.id,
                  onTap: () => setState(() => _selected = opt.id),
                );
              },
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s6),
            child: GSButton(
              label: 'View Route Details',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.routeDetail),
              leadingIcon: Icons.navigation_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationInputs extends StatelessWidget {
  const _LocationInputs({
    required this.originCtrl,
    required this.destCtrl,
  });
  final TextEditingController originCtrl;
  final TextEditingController destCtrl;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      margin: const EdgeInsets.all(GSSpacing.s5),
      padding: const EdgeInsets.all(GSSpacing.s4),
      shadow: GSShadow.md,
      child: Row(
        children: [
          // Dot connector
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: GSColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 36,
                color: GSColors.border,
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: GSColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              children: [
                GSTextField(hint: 'Origin', controller: originCtrl),
                const SizedBox(height: GSSpacing.s3),
                GSTextField(hint: 'Destination', controller: destCtrl),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded, color: GSColors.textSecondary),
            onPressed: () {
              final tmp = originCtrl.text;
              originCtrl.text = destCtrl.text;
              destCtrl.text = tmp;
            },
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });
  final _RouteOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GSDuration.normal,
        padding: const EdgeInsets.all(GSSpacing.s4),
        decoration: BoxDecoration(
          color: isSelected ? GSColors.primaryLight : GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          border: Border.all(
            color: isSelected ? GSColors.primary : GSColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? GSShadow.primary : GSShadow.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: option.iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(GSRadius.sm),
                  ),
                  child: Icon(option.icon, color: option.iconColor, size: 20),
                ),
                const SizedBox(width: GSSpacing.s3),
                Text(option.label,
                    style: const TextStyle(
                      
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: GSColors.textPrimary,
                    )),
                const Spacer(),
                // Stats
                _StatBadge(Icons.access_time_rounded, option.time),
                const SizedBox(width: GSSpacing.s2),
                _StatBadge(Icons.attach_money_rounded, option.cost,
                    color: GSColors.eco),
              ],
            ),
            const SizedBox(height: GSSpacing.s4),

            // Timeline
            Row(
              children: option.steps.map((s) {
                final isLast = s == option.steps.last;
                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: s.color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(s.icon, size: 16, color: s.color),
                          ),
                          const SizedBox(height: 4),
                          Text(s.duration,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: GSColors.textSecondary)),
                          Text(s.label,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: GSColors.textPrimary)),
                        ],
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 28),
                            color: GSColors.border,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: GSSpacing.s3),

            // CO2
            Row(
              children: [
                const Icon(Icons.eco_rounded, size: 14, color: GSColors.eco),
                const SizedBox(width: 4),
                Text('${option.co2} CO₂',
                    style: const TextStyle(
                        fontSize: 12, color: GSColors.eco,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge(this.icon, this.label, {this.color = GSColors.primary});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _RouteOption {
  final String id;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String time;
  final String cost;
  final String co2;
  final List<_Step> steps;
  const _RouteOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.cost,
    required this.co2,
    required this.steps,
  });
}

class _Step {
  final String label;
  final String duration;
  final IconData icon;
  final Color color;
  const _Step(this.label, this.duration, this.icon, this.color);
}
