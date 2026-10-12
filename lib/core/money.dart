// lib/core/money.dart
// Formato de pesos colombianos: "$37.000". Sin decimales, punto de miles.

/// 37000 → "$37.000"; -2500 → "−$2.500" (signo menos tipográfico).
String formatCop(num amount, {bool signed = false}) {
  final digits = amount.abs().round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
  if (amount < 0) return '−\$$digits';
  if (signed && amount > 0) return '+\$$digits';
  return '\$$digits';
}
