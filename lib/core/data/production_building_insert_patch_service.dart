import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_list_item_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

class ProductionBuildingPatchMetadata {
  final String cityName;
  final String typeName;
  final String typeIcon;

  const ProductionBuildingPatchMetadata({
    required this.cityName,
    required this.typeName,
    required this.typeIcon,
  });
}

/// Resolves display-only metadata that is intentionally absent from raw DB
/// row patches. Returning null means the caller should use a targeted refresh
/// instead of inserting a placeholder model into local state.
ProductionBuildingPatchMetadata? resolveProductionBuildingPatchMetadata({
  required StaticCatalogBundle catalogs,
  required String entity,
  required Map<String, dynamic> changes,
}) {
  final cityId = changes['city_id']?.toString() ?? '';
  final city = catalogs.cities.where((item) => item.id == cityId).firstOrNull;
  if (city == null) return null;

  String typeIdKey;
  List<Map<String, dynamic>> typeRows;
  switch (entity) {
    case 'factory':
      typeIdKey = 'factory_type_id';
      typeRows = catalogs.factoryTypes;
      break;
    case 'mine':
      typeIdKey = 'mine_type_id';
      typeRows = catalogs.mineTypes;
      break;
    case 'field':
      typeIdKey = 'field_type_id';
      typeRows = catalogs.fieldTypes;
      break;
    case 'farm':
      typeIdKey = 'farm_type_id';
      typeRows = catalogs.farmTypes;
      break;
    default:
      return null;
  }

  final typeId = changes[typeIdKey]?.toString() ?? '';
  Map<String, dynamic>? typeRow;
  for (final row in typeRows) {
    if (row['id']?.toString() == typeId) {
      typeRow = row;
      break;
    }
  }
  if (typeRow == null) return null;

  final typeName = typeRow['name']?.toString().trim() ?? '';
  final typeIcon = typeRow['icon']?.toString().trim() ?? '';
  if (typeName.isEmpty || typeIcon.isEmpty) return null;

  return ProductionBuildingPatchMetadata(
    cityName: city.name,
    typeName: typeName,
    typeIcon: typeIcon,
  );
}

/// Handles raw insert patches for production buildings without forcing a full
/// list refetch. Factory/Mine previously inserted placeholder city/type data;
/// Field/Farm previously refetched the whole list. Both behaviours undermine
/// the patch-first contract.
///
/// The service also handles Field/Farm `production_slot` inserts because their
/// initial slot used to be populated only indirectly by the full-list refetch.
class ProductionBuildingInsertPatchService {
  ProductionBuildingInsertPatchService(this._ref);

  final Ref _ref;

  bool apply(EntityPatch patch) {
    if (patch.operation != PatchOperation.insert) return false;

    if (patch.entity == 'production_slot') {
      return _applyAgriculturalSlotInsert(patch);
    }

    if (patch.entity != 'factory' &&
        patch.entity != 'mine' &&
        patch.entity != 'field' &&
        patch.entity != 'farm') {
      return false;
    }

    final catalogs = _ref.read(staticCatalogsProvider).value;
    if (catalogs == null) {
      _refreshProductionList(patch.entity);
      return true;
    }

    final metadata = resolveProductionBuildingPatchMetadata(
      catalogs: catalogs,
      entity: patch.entity,
      changes: patch.changes,
    );
    if (metadata == null) {
      _refreshProductionList(patch.entity);
      return true;
    }

    switch (patch.entity) {
      case 'factory':
        _insertFactory(patch, metadata);
        return true;
      case 'mine':
        _insertMine(patch, metadata);
        return true;
      case 'field':
        _insertField(patch, metadata);
        return true;
      case 'farm':
        _insertFarm(patch, metadata);
        return true;
    }
    return false;
  }

  void _insertFactory(
    EntityPatch patch,
    ProductionBuildingPatchMetadata metadata,
  ) {
    final current = _ref.read(factoryListProvider).value;
    if (current == null || current.any((item) => item.factory.id == patch.id)) {
      return;
    }
    final factory = FactoryModel.fromJson({...patch.changes, 'id': patch.id});
    _ref.read(factoryListProvider.notifier).addFactory(
          FactoryListItemModel(
            factory: factory,
            cityName: metadata.cityName,
            factoryTypeName: metadata.typeName,
            factoryTypeIcon: metadata.typeIcon,
            inputStockQuantity: 0,
            outputStockQuantity: 0,
            selectedProduct: null,
            productionSlots: const [],
          ),
        );
  }

  void _insertMine(
    EntityPatch patch,
    ProductionBuildingPatchMetadata metadata,
  ) {
    final current = _ref.read(mineListProvider).value;
    if (current == null || current.any((item) => item.mine.id == patch.id)) {
      return;
    }
    final mine = MineModel.fromJson({...patch.changes, 'id': patch.id});
    _ref.read(mineListProvider.notifier).addMine(
          MineListItemModel(
            mine: mine,
            cityName: metadata.cityName,
            mineTypeName: metadata.typeName,
            mineTypeIcon: metadata.typeIcon,
            outputStockQuantity: 0,
            selectedProduct: null,
            productionSlots: const [],
          ),
        );
  }

  void _insertField(
    EntityPatch patch,
    ProductionBuildingPatchMetadata metadata,
  ) {
    final current = _ref.read(fieldListProvider).value;
    if (current == null || current.any((item) => item.field.id == patch.id)) {
      return;
    }
    final field = FieldModel.fromJson({...patch.changes, 'id': patch.id});
    _ref.read(fieldListProvider.notifier).addField(
          FieldListItemModel(
            field: field,
            cityName: metadata.cityName,
            fieldTypeName: metadata.typeName,
            fieldTypeIcon: metadata.typeIcon,
            outputStockQuantity: 0,
            inputStockQuantity: 0,
            slots: const [],
          ),
        );
  }

  void _insertFarm(
    EntityPatch patch,
    ProductionBuildingPatchMetadata metadata,
  ) {
    final current = _ref.read(farmListProvider).value;
    if (current == null || current.any((item) => item.farm.id == patch.id)) {
      return;
    }
    final farm = FarmModel.fromJson({...patch.changes, 'id': patch.id});
    _ref.read(farmListProvider.notifier).addFarm(
          FarmListItemModel(
            farm: farm,
            cityName: metadata.cityName,
            farmTypeName: metadata.typeName,
            farmTypeIcon: metadata.typeIcon,
            outputStockQuantity: 0,
            inputStockQuantity: 0,
            slots: const [],
          ),
        );
  }

  bool _applyAgriculturalSlotInsert(EntityPatch patch) {
    final ownerKind = patch.changes['owner_kind']?.toString() ?? '';
    final ownerId = patch.changes['owner_id']?.toString() ?? '';
    if (ownerId.isEmpty || (ownerKind != 'field' && ownerKind != 'farm')) {
      return false;
    }

    final productId = patch.changes['product_id']?.toString();
    final product = _resolveProduct(productId);
    final payload = <String, dynamic>{
      ...patch.changes,
      'id': patch.id,
      if (product != null) 'product': product.toJson(),
    };

    if (ownerKind == 'field') {
      final slot = ProductionSlotModel.fromJson(payload);
      _ref
          .read(fieldListProvider.notifier)
          .addSlot(
            fieldId: ownerId,
            slot: FieldSlotPreviewModel(
              id: slot.id,
              slotIndex: slot.slotIndex,
              isActive: slot.isActive,
              productId: slot.productId,
              product: slot.product,
            ),
          );
      final detail = _ref.read(fieldDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(fieldDetailProvider(ownerId).notifier).addSlot(slot);
      }
      return true;
    }

    final slot = FarmProductionSlotModel.fromJson(payload);
    _ref
        .read(farmListProvider.notifier)
        .addSlot(
          farmId: ownerId,
          slot: FarmSlotPreviewModel(
            id: slot.id,
            slotIndex: slot.slotIndex,
            isActive: slot.isActive,
            productId: slot.productId,
            product: slot.product,
          ),
        );
    final detail = _ref.read(farmDetailProvider(ownerId)).value;
    if (detail != null) {
      _ref.read(farmDetailProvider(ownerId).notifier).addSlot(slot);
    }
    return true;
  }

  ProductModel? _resolveProduct(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    final catalogs = _ref.read(staticCatalogsProvider).value;
    if (catalogs == null) return null;
    for (final product in catalogs.products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  void _refreshProductionList(String entity) {
    switch (entity) {
      case 'factory':
        _ref.invalidate(factoryListProvider);
        break;
      case 'mine':
        _ref.invalidate(mineListProvider);
        break;
      case 'field':
        _ref.invalidate(fieldListProvider);
        break;
      case 'farm':
        _ref.invalidate(farmListProvider);
        break;
    }
  }
}

final productionBuildingInsertPatchServiceProvider =
    Provider<ProductionBuildingInsertPatchService>(
  ProductionBuildingInsertPatchService.new,
);
