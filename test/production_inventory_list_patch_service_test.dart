import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/production_inventory_list_patch_service.dart';

void main() {
  test('input and output totals include every physical inventory row', () {
    final totals = calculateProductionInventoryTotals(const [
      (inventoryType: 'input', quantity: 30),
      (inventoryType: 'input', quantity: 7),
      (inventoryType: 'output', quantity: 50),
      (inventoryType: 'output', quantity: 13),
    ]);

    expect(totals.inputQuantity, 37);
    expect(totals.outputQuantity, 63);
  });

  test('unknown inventory types do not contaminate card aggregates', () {
    final totals = calculateProductionInventoryTotals(const [
      (inventoryType: 'input', quantity: 10),
      (inventoryType: 'reserved', quantity: 999),
      (inventoryType: 'output', quantity: 20),
    ]);

    expect(totals.inputQuantity, 10);
    expect(totals.outputQuantity, 20);
  });

  test('fallback invalidation accumulator collapses duplicate owner kinds', () {
    final accumulator = ProductionInventoryFallbackInvalidationAccumulator();

    expect(accumulator.add('factory'), isTrue);
    expect(accumulator.add('factory'), isFalse);
    expect(accumulator.add('farm'), isTrue);
    expect(accumulator.add(''), isFalse);

    expect(accumulator.drain(), {'factory', 'farm'});
    expect(accumulator.drain(), isEmpty);
    expect(accumulator.add('factory'), isTrue);
  });
}
