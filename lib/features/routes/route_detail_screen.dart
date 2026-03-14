import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../router/app_router.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({super.key});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  int _selectedDriver = 0;

  static const _drivers = [
    _Driver(
      name: 'Carlos Santos',
      rating: '99% Smooth Ride',
      price: '\$30/h',
      vehicleName: 'Porsche Taycan',
      waitTime: '25 mins',
      avatarColor: GSColors.accent,
    ),
    _Driver(
      name: 'Lucas Martinez',
      rating: '93% Smooth Ride',
      price: '\$35/h',
      vehicleName: 'Tesla Model 3',
      waitTime: '12 mins',
      avatarColor: GSColors.eco,
    ),
    _Driver(
      name: 'Ana Reyes',
      rating: '97% Smooth Ride',
      price: '\$28/h',
      vehicleName: 'Hyundai Ioniq',
      waitTime: '8 mins',
      avatarColor: GSColors.taxi,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Choose a driver'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(GSSpacing.s5),
              itemCount: _drivers.length,
              separatorBuilder: (_, __) => const SizedBox(height: GSSpacing.s4),
              itemBuilder: (_, i) {
                final d = _drivers[i];
                return _DriverCard(
                  driver: d,
                  isSelected: _selectedDriver == i,
                  onTap: () => setState(() => _selectedDriver = i),
                  onBook: () => _showBookingSheet(context, d),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s6),
            child: GSButton(
              label: 'Book — ${_drivers[_selectedDriver].price}',
              onPressed: () => _showBookingSheet(
                  context, _drivers[_selectedDriver]),
              leadingIcon: Icons.check_rounded,
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(BuildContext context, _Driver driver) {
    GSBottomSheet.show(
      context: context,
      title: 'Confirm booking',
      initialChildSize: 0.55,
      child: Column(
        children: [
          // Driver summary
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: driver.avatarColor.withOpacity(0.12),
                child: Icon(Icons.person_rounded,
                    color: driver.avatarColor, size: 30),
              ),
              const SizedBox(width: GSSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name,
                        style: const TextStyle(
                          
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: GSColors.textPrimary,
                        )),
                    Text(driver.vehicleName,
                        style: const TextStyle(
                            fontSize: 14, color: GSColors.textSecondary)),
                    Text(driver.rating,
                        style: const TextStyle(
                            fontSize: 13, color: GSColors.eco,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(driver.price,
                  style: const TextStyle(
                    
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: GSColors.accent,
                  )),
            ],
          ),
          const SizedBox(height: GSSpacing.s5),
          const Divider(),
          const SizedBox(height: GSSpacing.s4),

          // Details
          _DetailRow(Icons.access_time_rounded, 'Estimated wait',
              driver.waitTime),
          const SizedBox(height: GSSpacing.s3),
          const _DetailRow(Icons.route_rounded, 'Distance', '14.2 km'),
          const SizedBox(height: GSSpacing.s3),
          const _DetailRow(
              Icons.account_balance_wallet_rounded, 'Payment', 'GoSmart Card'),
          const SizedBox(height: GSSpacing.s5),

          GSButton(
            label: 'Confirm & Pay',
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRoutes.paymentValidation);
            },
            leadingIcon: Icons.payment_rounded,
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.isSelected,
    required this.onTap,
    required this.onBook,
  });
  final _Driver driver;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GSDuration.normal,
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          border: Border.all(
            color: isSelected ? GSColors.accent : GSColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? GSShadow.primary : GSShadow.md,
        ),
        padding: const EdgeInsets.all(GSSpacing.s4),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: driver.avatarColor.withOpacity(0.12),
                  child: Icon(Icons.person_rounded,
                      color: driver.avatarColor, size: 24),
                ),
                const SizedBox(width: GSSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: GSColors.textPrimary,
                          )),
                      Text(driver.rating,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GSColors.textSecondary,
                          )),
                    ],
                  ),
                ),
                Text(driver.price,
                    style: const TextStyle(

                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: GSColors.accent,
                    )),
              ],
            ),
            const SizedBox(height: GSSpacing.s3),

            // Vehicle image placeholder
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: GSColors.surfaceDark,
                borderRadius: BorderRadius.circular(GSRadius.md),
                gradient: LinearGradient(
                  colors: [
                    driver.avatarColor.withOpacity(0.05),
                    driver.avatarColor.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_rounded,
                      size: 64, color: driver.avatarColor.withOpacity(0.5)),
                  const SizedBox(height: 4),
                  Text(driver.vehicleName,
                      style: TextStyle(
                          
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: driver.avatarColor)),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s3),

            // Footer
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 14, color: GSColors.textSecondary),
                const SizedBox(width: 4),
                Text(driver.waitTime,
                    style: const TextStyle(
                        fontSize: 13, color: GSColors.textSecondary)),
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GSRadius.full),
                      ),
                    ),
                    child: const Text('Book Now',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: GSColors.textSecondary),
        const SizedBox(width: GSSpacing.s3),
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: GSColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: GSColors.textPrimary,
            )),
      ],
    );
  }
}

class _Driver {
  final String name;
  final String rating;
  final String price;
  final String vehicleName;
  final String waitTime;
  final Color avatarColor;
  const _Driver({
    required this.name,
    required this.rating,
    required this.price,
    required this.vehicleName,
    required this.waitTime,
    required this.avatarColor,
  });
}
