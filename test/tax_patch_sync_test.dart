import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';

void main() {
  test('tax debt patch reads current backend tax_debt field', () {
    expect(taxDebtFromPatch({'tax_debt': 1250}), 1250.0);
    expect(taxDebtFromPatch({'tax_debt': 87.5}), 87.5);
  });

  test('tax debt patch keeps legacy current_tax_debt compatibility', () {
    expect(taxDebtFromPatch({'current_tax_debt': 500}), 500.0);
  });

  test('unrelated or malformed patch does not invent a debt value', () {
    expect(taxDebtFromPatch({'tax_limit': 10000}), isNull);
    expect(taxDebtFromPatch({'tax_debt': 'not-a-number'}), isNull);
  });
}
