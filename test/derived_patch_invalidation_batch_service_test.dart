import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/derived_patch_invalidation_batch_service.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';

void main() {
  test('planner deduplicates transfer, finance and performance invalidations', () {
    final plan = planDerivedPatchInvalidations(const [
      EntityPatch(
        entity: 'logistics_transfer_item',
        operation: PatchOperation.insert,
        id: 'item-1',
        changes: {'transfer_id': 'transfer-1'},
      ),
      EntityPatch(
        entity: 'logistics_transfer_item',
        operation: PatchOperation.insert,
        id: 'item-2',
        changes: {'transfer_id': 'transfer-1'},
      ),
      EntityPatch(
        entity: 'logistics_finance_entry',
        operation: PatchOperation.insert,
        id: 'finance-1',
        changes: {},
      ),
      EntityPatch(
        entity: 'logistics_finance_entry',
        operation: PatchOperation.insert,
        id: 'finance-2',
        changes: {},
      ),
      EntityPatch(
        entity: 'store_daily_performance',
        operation: PatchOperation.update,
        id: 'perf-1',
        changes: {'store_id': 'store-1'},
      ),
      EntityPatch(
        entity: 'store_daily_performance',
        operation: PatchOperation.update,
        id: 'perf-2',
        changes: {'store_id': 'store-1'},
      ),
    ]);

    expect(plan.transferIds, {'transfer-1'});
    expect(plan.logisticsFinanceDirty, isTrue);
    expect(plan.storePerformanceIds, {'store-1'});
  });

  test('only derived-only entities bypass the legacy dispatcher', () {
    expect(isDerivedOnlyPatchEntity('logistics_transfer_item'), isTrue);
    expect(isDerivedOnlyPatchEntity('logistics_finance_entry'), isTrue);
    expect(isDerivedOnlyPatchEntity('store_daily_performance'), isTrue);
    expect(isDerivedOnlyPatchEntity('warehouse_slot'), isFalse);
    expect(isDerivedOnlyPatchEntity('production_inventory'), isFalse);
  });
}
