import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';

typedef IndustrialProductionSlotOwner = ({
  String ownerKind,
  String ownerId,
});

String _ownerKey(String ownerKind, String ownerId) => '$ownerKind:$ownerId';

class IndustrialProductionSlotRegistry
    extends Notifier<Map<String, List<ProductionSlotContractModel>>> {
  @override
  Map<String, List<ProductionSlotContractModel>> build() => const {};

  List<ProductionSlotContractModel> slotsFor({
    required String ownerKind,
    required String ownerId,
  }) {
    return state[_ownerKey(ownerKind, ownerId)] ?? const [];
  }

  void seed({
    required String ownerKind,
    required String ownerId,
    required List<ProductionSlotContractModel> slots,
  }) {
    if (!_isIndustrial(ownerKind) || ownerId.isEmpty) return;
    final sorted = [...slots]..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    state = {
      ...state,
      _ownerKey(ownerKind, ownerId): List.unmodifiable(sorted),
    };
  }

  bool containsSlot(String slotId) {
    if (slotId.isEmpty) return false;
    return state.values.any((slots) => slots.any((slot) => slot.id == slotId));
  }

  IndustrialProductionSlotOwner? ownerForSlot(String slotId) {
    for (final entry in state.entries) {
      if (entry.value.any((slot) => slot.id == slotId)) {
        final separator = entry.key.indexOf(':');
        if (separator <= 0 || separator >= entry.key.length - 1) return null;
        return (
          ownerKind: entry.key.substring(0, separator),
          ownerId: entry.key.substring(separator + 1),
        );
      }
    }
    return null;
  }

  void insert(
    ProductionSlotContractModel slot, {
    ProductModel? resolvedProduct,
  }) {
    if (!_isIndustrial(slot.ownerKind) || slot.ownerId.isEmpty) return;
    final key = _ownerKey(slot.ownerKind, slot.ownerId);
    final current = state[key] ?? const [];
    final normalized = slot.product == null && resolvedProduct != null
        ? slot.applyPatch(const {}, resolvedProduct: resolvedProduct)
        : slot;
    final next = current.where((item) => item.id != normalized.id).toList()
      ..add(normalized)
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    state = {...state, key: List.unmodifiable(next)};
  }

  void update({
    required String slotId,
    required Map<String, dynamic> changes,
    ProductModel? resolvedProduct,
  }) {
    final explicitKind = changes['owner_kind']?.toString() ?? '';
    final explicitId = changes['owner_id']?.toString() ?? '';
    final owner = _isIndustrial(explicitKind) && explicitId.isNotEmpty
        ? (ownerKind: explicitKind, ownerId: explicitId)
        : ownerForSlot(slotId);
    if (owner == null) return;

    final key = _ownerKey(owner.ownerKind, owner.ownerId);
    final current = state[key] ?? const [];
    final index = current.indexWhere((slot) => slot.id == slotId);
    if (index < 0) return;

    final next = [...current];
    next[index] = next[index].applyPatch(
      changes,
      resolvedProduct: resolvedProduct,
    );
    next.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    state = {...state, key: List.unmodifiable(next)};
  }

  void remove({
    required String slotId,
    String? ownerKind,
    String? ownerId,
  }) {
    final owner = _isIndustrial(ownerKind ?? '') && (ownerId ?? '').isNotEmpty
        ? (ownerKind: ownerKind!, ownerId: ownerId!)
        : ownerForSlot(slotId);
    if (owner == null) return;

    final key = _ownerKey(owner.ownerKind, owner.ownerId);
    final current = state[key] ?? const [];
    final next = current.where((slot) => slot.id != slotId).toList();
    if (next.length == current.length) return;
    state = {...state, key: List.unmodifiable(next)};
  }

  static bool _isIndustrial(String ownerKind) =>
      ownerKind == 'factory' || ownerKind == 'mine';
}

final industrialProductionSlotRegistryProvider = NotifierProvider<
    IndustrialProductionSlotRegistry,
    Map<String, List<ProductionSlotContractModel>>>(
  IndustrialProductionSlotRegistry.new,
);

final industrialProductionSlotsProvider = Provider.family<
    List<ProductionSlotContractModel>,
    IndustrialProductionSlotOwner>((ref, owner) {
  final registry = ref.watch(industrialProductionSlotRegistryProvider);
  return registry[_ownerKey(owner.ownerKind, owner.ownerId)] ?? const [];
});

class IndustrialProductionSlotPatchService {
  IndustrialProductionSlotPatchService(this._ref);

  final Ref _ref;

  /// Applies only the additional Factory/Mine state that the legacy central
  /// dispatcher does not yet understand.
  ///
  /// Returns true only when a production_slot patch belongs to Factory/Mine and
  /// is fully handled here. The caller can then skip the legacy Field/Farm
  /// production-slot handler and avoid unnecessary provider lookups.
  bool apply(EntityPatch patch) {
    if (patch.entity == 'production_slot') {
      return _applyProductionSlotPatch(patch);
    }

    if (patch.entity == 'factory' || patch.entity == 'mine') {
      _applyOwnerSlotCountPatch(patch);
    }
    return false;
  }

  bool _applyProductionSlotPatch(EntityPatch patch) {
    final changes = patch.changes;
    final registry = _ref.read(industrialProductionSlotRegistryProvider.notifier);
    final explicitKind = changes['owner_kind']?.toString() ?? '';
    final explicitId = changes['owner_id']?.toString() ?? '';

    IndustrialProductionSlotOwner? owner;
    if (_isIndustrial(explicitKind) && explicitId.isNotEmpty) {
      owner = (ownerKind: explicitKind, ownerId: explicitId);
    } else {
      owner = registry.ownerForSlot(patch.id) ?? _ownerFromLoadedLists(patch.id);
    }
    if (owner == null) return false;

    // Market and list pages can be loaded without the detail-screen registry.
    // Seed from the list payload before applying an update/delete patch so both
    // representations advance from the same slot snapshot.
    if (registry.slotsFor(
      ownerKind: owner.ownerKind,
      ownerId: owner.ownerId,
    ).isEmpty) {
      final listSlots = _slotsFromLoadedList(owner);
      if (listSlots.isNotEmpty) {
        registry.seed(
          ownerKind: owner.ownerKind,
          ownerId: owner.ownerId,
          slots: listSlots,
        );
      }
    }

    final productId = changes['product_id']?.toString();
    final resolvedProduct = _resolveProduct(productId);

    switch (patch.operation) {
      case PatchOperation.insert:
        final payload = <String, dynamic>{
          ...changes,
          'id': patch.id,
          'owner_kind': owner.ownerKind,
          'owner_id': owner.ownerId,
        };
        final slot = ProductionSlotContractModel.fromJson(payload);
        registry.insert(slot, resolvedProduct: resolvedProduct);
        break;
      case PatchOperation.update:
        registry.update(
          slotId: patch.id,
          changes: {
            ...changes,
            'owner_kind': owner.ownerKind,
            'owner_id': owner.ownerId,
          },
          resolvedProduct: resolvedProduct,
        );
        break;
      case PatchOperation.delete:
        registry.remove(
          slotId: patch.id,
          ownerKind: owner.ownerKind,
          ownerId: owner.ownerId,
        );
        break;
    }

    _syncLoadedListSlots(
      owner,
      registry.slotsFor(
        ownerKind: owner.ownerKind,
        ownerId: owner.ownerId,
      ),
    );
    return true;
  }

  IndustrialProductionSlotOwner? _ownerFromLoadedLists(String slotId) {
    final factories = _ref.read(factoryListProvider).value;
    if (factories != null) {
      for (final item in factories) {
        if (item.productionSlots.any((slot) => slot.id == slotId)) {
          return (ownerKind: 'factory', ownerId: item.factory.id);
        }
      }
    }

    final mines = _ref.read(mineListProvider).value;
    if (mines != null) {
      for (final item in mines) {
        if (item.productionSlots.any((slot) => slot.id == slotId)) {
          return (ownerKind: 'mine', ownerId: item.mine.id);
        }
      }
    }
    return null;
  }

  List<ProductionSlotContractModel> _slotsFromLoadedList(
    IndustrialProductionSlotOwner owner,
  ) {
    if (owner.ownerKind == 'factory') {
      final factories = _ref.read(factoryListProvider).value;
      if (factories == null) return const [];
      for (final item in factories) {
        if (item.factory.id == owner.ownerId) return item.productionSlots;
      }
      return const [];
    }

    final mines = _ref.read(mineListProvider).value;
    if (mines == null) return const [];
    for (final item in mines) {
      if (item.mine.id == owner.ownerId) return item.productionSlots;
    }
    return const [];
  }

  void _syncLoadedListSlots(
    IndustrialProductionSlotOwner owner,
    List<ProductionSlotContractModel> slots,
  ) {
    if (owner.ownerKind == 'factory') {
      final items = _ref.read(factoryListProvider).value;
      if (items == null) return;
      final index = items.indexWhere((item) => item.factory.id == owner.ownerId);
      if (index < 0) return;
      _ref.read(factoryListProvider.notifier).replaceFactory(
            items[index].copyWith(productionSlots: slots),
          );
      return;
    }

    final items = _ref.read(mineListProvider).value;
    if (items == null) return;
    final index = items.indexWhere((item) => item.mine.id == owner.ownerId);
    if (index < 0) return;
    _ref.read(mineListProvider.notifier).replaceMine(
          items[index].copyWith(productionSlots: slots),
        );
  }

  void _applyOwnerSlotCountPatch(EntityPatch patch) {
    if (patch.operation != PatchOperation.update) return;
    if (!patch.changes.containsKey('current_slot_count') &&
        !patch.changes.containsKey('max_slot_count')) {
      return;
    }

    final currentSlotCount =
        (patch.changes['current_slot_count'] as num?)?.toInt();
    final maxSlotCount = (patch.changes['max_slot_count'] as num?)?.toInt();

    if (patch.entity == 'factory') {
      final items = _ref.read(factoryListProvider).value;
      if (items == null) return;
      final index = items.indexWhere((item) => item.factory.id == patch.id);
      if (index < 0) return;
      final item = items[index];
      _ref.read(factoryListProvider.notifier).replaceFactory(
            item.copyWith(
              factory: item.factory.copyWith(
                currentSlotCount:
                    currentSlotCount ?? item.factory.currentSlotCount,
                maxSlotCount: maxSlotCount ?? item.factory.maxSlotCount,
              ),
            ),
          );
      return;
    }

    final items = _ref.read(mineListProvider).value;
    if (items == null) return;
    final index = items.indexWhere((item) => item.mine.id == patch.id);
    if (index < 0) return;
    final item = items[index];
    _ref.read(mineListProvider.notifier).replaceMine(
          item.copyWith(
            mine: item.mine.copyWith(
              currentSlotCount: currentSlotCount ?? item.mine.currentSlotCount,
              maxSlotCount: maxSlotCount ?? item.mine.maxSlotCount,
            ),
          ),
        );
  }

  bool _isIndustrial(String ownerKind) =>
      ownerKind == 'factory' || ownerKind == 'mine';

  ProductModel? _resolveProduct(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    final catalogs = _ref.read(staticCatalogsProvider).value;
    if (catalogs == null) return null;
    try {
      return catalogs.products.firstWhere((product) => product.id == productId);
    } catch (_) {
      return null;
    }
  }
}

final industrialProductionSlotPatchServiceProvider =
    Provider<IndustrialProductionSlotPatchService>((ref) {
  return IndustrialProductionSlotPatchService(ref);
});
