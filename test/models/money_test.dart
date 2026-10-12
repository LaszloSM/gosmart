import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/money.dart';

void main() {
  test('formatCop usa punto de miles y sin decimales', () {
    expect(formatCop(0), '\$0');
    expect(formatCop(950), '\$950');
    expect(formatCop(37000), '\$37.000');
    expect(formatCop(1234567), '\$1.234.567');
  });

  test('formatCop con signo', () {
    expect(formatCop(10000, signed: true), '+\$10.000');
    expect(formatCop(-2500), '−\$2.500');
    expect(formatCop(-2500, signed: true), '−\$2.500');
    expect(formatCop(0, signed: true), '\$0');
  });
}
