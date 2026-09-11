import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';

class DerivedPatchInvalidationPlan {
  final Set<String> transferIds;
  final Set<String> storePerformanceIds;
  final bool logisticsFinanceDirty;
  final bool marketListingInsertDirty;

  const DerivedPatchInvalidationPlan({
    required this.transferIds,
    required this.storePerformanceIds,
    required this.logisticsFinanceDirty,
    required this.marketListingInsertDirty,
  });
}

bool isDerivedOnlyPatchEntity(String entity) {
  return entity == 'logistics_transfer_item' ||
      entity == 'logistics_finance_entry' ||
      entity == 'store_daily_performance';
}

/// Market listing updates/deletes mutate loaded local models and must still go
/// through the dispatcher. Inserts are different: the raw DB row intentionally
/// lacks the enriched market read-model fields, so the dispatcher only triggers
/// filtered-list refreshes. Multiple inserts from one mutation can therefore be
/// safely collapsed into a single refresh wave.
bool shouldBatchDerivedPatch(EntityPatch patch) {
  if (isDerivedOnlyPatchEntity(patch.entity)) return true;
  return patch.entity == 'market_listing' &&
      patch.operation == PatchOperation.insert;
}

DerivedPatchInvalidationPlan planDerivedPatchInvalidations(
  Iterable<EntityPatch> patches,
) {
  final transferIds = <String>{};
  final storePerformanceIds = <String>{};
  var logisticsFinanceDirty = false;
  var marketListingInsertDirty = false;

  for (final patch in patches) {
    switch (patch.entity) {
      case 'logistics_transfer_item':
        final transferId = patch.changes['transfer_id']?.toString().trim() ?? '';
        if (transferId.isNotEmpty) transferIds.add(transferId);
        break;
      case 'logistics_finance_entry':
        logisticsFinanceDirty = true;
        break;
      case 'store_daily_performance':
        final storeId =
            patch.changes['store_id']?.toString().trim() ?? patch.id.trim();
        if (storeId.isNotEmpty) storePerformanceIds.add(storeId);
        break;
      case 'market_listing':
        if (patch.operation == PatchOperation.insert) {
          marketListingInsertDirty = true;
        }
        break;
    }
  }

  return DerivedPatchInvalidationPlan(
    transferIds: transferIds,
    storePerformanceIds: storePerformanceIds,
    logisticsFinanceDirty: logisticsFinanceDirty,
    marketListingInsertDirty: marketListingInsertDirty,
  );
}

/// Some patch entities are derived/read-model invalidation signals rather than
/// local model mutations. The legacy dispatcher invalidates their providers once
/// per patch, which can trigger repeated fetches when a single RPC returns many
/// transfer items, finance rows or newly-created market listings. This service
/// collapses them per mutation.
class DerivedPatchInvalidationBatchService {
  DerivedPatchInvalidationBatchService(this._ref);

  final Ref _ref;

  bool handles(EntityPatch patch) => shouldBatchDerivedPatch(patch);

  void apply(Iterable<EntityPatch> patches) {
    final patchList = patches.toList(growable: false);
    final plan = planDerivedPatchInvalidations(patchList);

    for (final transferId in plan.transferIds) {
      _ref.invalidate(transferItemsProvider(transferId));
    }

    if (plan.logisticsFinanceDirty) {
      _ref.invalidate(logisticsFinanceEntriesProvider);
      _ref.invalidate(logisticsFinanceSummaryProvider);
    }

    for (final storeId in plan.storePerformanceIds) {
      _ref.invalidate(storePerformanceProvider(storeId));
    }

    if (plan.marketListingInsertDirty) {
      final firstInsert = patchList.firstWhere(
        (patch) =>
            patch.entity == 'market_listing' &&
            patch.operation == PatchOperation.insert,
      );
      _ref
          .read(marketListingsPatchRegistryProvider)
          .handleInsertOrRefresh(firstInsert);
    }
  }
}

final derivedPatchInvalidationBatchServiceProvider =
    Provider<DerivedPatchInvalidationBatchService>(
  DerivedPatchInvalidationBatchService.new,
);
