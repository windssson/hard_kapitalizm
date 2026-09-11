import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

class StoreWarehouseInsertMetadata {
  final CityModel city;
  final StoreTypeModel? storeType;
  final Map<String, dynamic>? warehouseType;

  const StoreWarehouseInsertMetadata({
    required this.city,
    this.storeType,
    this.warehouseType,
  });
}

StoreWarehouseInsertMetadata? resolveStoreWarehouseInsertMetadata({
  required StaticCatalogBundle catalogs,
  required String entity,
  required Map<String, dynamic> changes,
}) {
  final cityId = changes['city_id']?.toString() ?? '';
  CityModel? city;
  for (final candidate in catalogs.cities) {
    if (candidate.id == cityId) {
      city = candidate;
      break;
    }
  }
  if (city == null) return null;

  if (entity == 'store') {
    final typeId = changes['store_type_id']?.toString() ?? '';
    StoreTypeModel? type;
    for (final candidate in catalogs.storeTypes) {
      if (candidate.id == typeId) {
        type = candidate;
        break;
      }
    }
    if (type == null) return null;
    return StoreWarehouseInsertMetadata(city: city, storeType: type);
  }

  if (entity == 'warehouse') {
    final typeId = changes['warehouse_type_id']?.toString() ?? '';
    Map<String, dynamic>? type;
    for (final candidate in catalogs.warehouseTypes) {
      if (candidate['id']?.toString() == typeId) {
        type = candidate;
        break;
      }
    }
    if (type == null) return null;
    return StoreWarehouseInsertMetadata(city: city, warehouseType: type);
  }

  return null;
}

/// Raw insert patches contain table columns only; list models additionally need
/// static city/type metadata. Applying the raw row directly used to create a
/// store with an empty StoreTypeModel or a warehouse with null city/type icon
/// until a refetch. This service enriches inserts from the already-loaded static
/// catalog and keeps the normal mutation path refetch-free.
class StoreWarehouseInsertPatchService {
  StoreWarehouseInsertPatchService(this._ref);

  final Ref _ref;

  bool apply(EntityPatch patch) {
    if (patch.operation != PatchOperation.insert ||
        (patch.entity != 'store' && patch.entity != 'warehouse')) {
      return false;
    }

    final catalogs = _ref.read(staticCatalogsProvider).value;
    if (catalogs == null) {
      _refreshList(patch.entity);
      return true;
    }

    final metadata = resolveStoreWarehouseInsertMetadata(
      catalogs: catalogs,
      entity: patch.entity,
      changes: patch.changes,
    );
    if (metadata == null) {
      _refreshList(patch.entity);
      return true;
    }

    if (patch.entity == 'store') {
      _insertStore(patch, metadata);
      return true;
    }

    _insertWarehouse(patch, metadata);
    return true;
  }

  void _insertStore(
    EntityPatch patch,
    StoreWarehouseInsertMetadata metadata,
  ) {
    final current = _ref.read(storesListProvider).value;
    if (current == null || current.any((store) => store.id == patch.id)) return;

    final payload = <String, dynamic>{
      ...patch.changes,
      'id': patch.id,
      'city_name': metadata.city.name,
      'city': metadata.city.toJson(),
      'store_type': metadata.storeType!.toJson(),
    };
    final store = StoreModel.fromJson(payload);
    _ref.read(storesListProvider.notifier).prependStore(store);
  }

  void _insertWarehouse(
    EntityPatch patch,
    StoreWarehouseInsertMetadata metadata,
  ) {
    final current = _ref.read(warehouseListProvider).value;
    if (current == null || current.any((warehouse) => warehouse.id == patch.id)) {
      return;
    }

    final payload = <String, dynamic>{
      ...patch.changes,
      'id': patch.id,
      'city': metadata.city.toJson(),
      'warehouse_type': metadata.warehouseType,
    };
    final warehouse = WarehouseModel.fromJson(payload);
    _ref.read(warehouseListProvider.notifier).prependWarehouse(warehouse);
  }

  void _refreshList(String entity) {
    if (entity == 'store') {
      _ref.invalidate(storesListProvider);
    } else if (entity == 'warehouse') {
      _ref.invalidate(warehouseListProvider);
    }
  }
}

final storeWarehouseInsertPatchServiceProvider =
    Provider<StoreWarehouseInsertPatchService>(
  StoreWarehouseInsertPatchService.new,
);
