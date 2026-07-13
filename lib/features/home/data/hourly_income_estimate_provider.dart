import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_list_item_model.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class HourlyIncomeEstimate {
  final double total;
  final double storeRevenue;
  final double productionValue;

  const HourlyIncomeEstimate({
    required this.total,
    required this.storeRevenue,
    required this.productionValue,
  });
}

final hourlyIncomeEstimateProvider =
    FutureProvider<HourlyIncomeEstimate>((ref) async {
      final storesFuture = ref.watch(storesListProvider.future);
      final factoriesFuture = ref.watch(factoryListProvider.future);
      final farmsFuture = ref.watch(farmListProvider.future);
      final fieldsFuture = ref.watch(fieldListProvider.future);
      final minesFuture = ref.watch(mineListProvider.future);
      final catalogsFuture = ref.watch(staticCatalogsProvider.future);

      final results = await Future.wait<dynamic>([
        storesFuture,
        factoriesFuture,
        farmsFuture,
        fieldsFuture,
        minesFuture,
        catalogsFuture,
      ]);

      final stores = results[0] as List<StoreModel>;
      final factories = results[1] as List<FactoryListItemModel>;
      final farms = results[2] as List<FarmListItemModel>;
      final fields = results[3] as List<FieldListItemModel>;
      final mines = results[4] as List<MineListItemModel>;
      final catalogs = results[5] as StaticCatalogBundle;

      final productsById = {
        for (final product in catalogs.products) product.id: product,
      };

      final storeRevenue = _estimateStoreRevenue(stores);
      final productionValue = _estimateProductionValue(
        factories: factories,
        farms: farms,
        fields: fields,
        mines: mines,
        productsById: productsById,
      );

      return HourlyIncomeEstimate(
        total: storeRevenue + productionValue,
        storeRevenue: storeRevenue,
        productionValue: productionValue,
      );
    });

double _estimateStoreRevenue(List<StoreModel> stores) {
  var total = 0.0;

  for (final store in stores) {
    if (!store.isActive || store.isUnderConstruction) continue;

    for (final slot in store.slots) {
      final product = slot.product;
      final price = slot.price ?? 0;
      if (!slot.isActive ||
          slot.isEmpty ||
          product == null ||
          slot.quantity <= 0 ||
          price <= 0) {
        continue;
      }

      final baseHourlyDemand = product.satisAdedi.toDouble();
      if (baseHourlyDemand <= 0) continue;

      final qualityMultiplier = 1 + ((slot.qualityLevel.clamp(1, 5) - 1) * 0.10);
      final brandedMultiplier = _isDefaultBrand(slot.brandId) ? 1.0 : 1.10;
      final priceMultiplier = _storePriceDemandMultiplier(
        price: price,
        referencePrice:
            product.bazSatisFiyati * _storeQualityPriceMultiplier(slot.qualityLevel),
      );
      final boostMultiplier = slot.boostMultiplier <= 0 ? 1.0 : slot.boostMultiplier;
      final demandPerHour = baseHourlyDemand *
          qualityMultiplier *
          brandedMultiplier *
          priceMultiplier *
          boostMultiplier;
      final estimatedUnits = demandPerHour.clamp(0, slot.quantity).toDouble();
      total += estimatedUnits * price;
    }
  }

  return total;
}

double _estimateProductionValue({
  required List<FactoryListItemModel> factories,
  required List<FarmListItemModel> farms,
  required List<FieldListItemModel> fields,
  required List<MineListItemModel> mines,
  required Map<String, ProductModel> productsById,
}) {
  var total = 0.0;

  for (final item in factories) {
    final product = item.selectedProduct;
    if (product == null || !item.factory.isActive || item.factory.productId == null) {
      continue;
    }
    if (item.outputStockRatio >= 0.98) continue;
    final requiresInput = product.inputProductIds.isNotEmpty;
    if (requiresInput && item.inputStockQuantity <= 0) continue;
    final capacityFactor = (1 - item.outputStockRatio).clamp(0.0, 1.0);
    total += _estimatedProductionUnitValue(
      product: product,
      multiplier: item.factory.boostMultiplier,
      capacityFactor: capacityFactor,
    );
  }

  for (final item in mines) {
    final product = item.selectedProduct;
    if (product == null || !item.mine.isActive || item.mine.productId == null) {
      continue;
    }
    if (item.outputStockRatio >= 0.98) continue;
    final capacityFactor = (1 - item.outputStockRatio).clamp(0.0, 1.0);
    total += _estimatedProductionUnitValue(
      product: product,
      multiplier: item.mine.boostMultiplier,
      capacityFactor: capacityFactor,
    );
  }

  for (final item in farms) {
    if (!item.farm.isActive || item.outputStockRatio >= 0.98) continue;
    final capacityFactor = (1 - item.outputStockRatio).clamp(0.0, 1.0);
    for (final slot in item.slots) {
      final product = slot.product;
      if (!slot.isActive || !slot.hasProduct || product == null) continue;
      final requiresInput = product.inputProductIds.isNotEmpty;
      if (requiresInput && item.inputStockQuantity <= 0) continue;
      total += _estimatedProductionUnitValue(
        product: productsById[product.id] ?? product,
        multiplier: 1.0,
        capacityFactor: capacityFactor,
      );
    }
  }

  for (final item in fields) {
    if (!item.field.isActive || item.outputStockRatio >= 0.98) continue;
    final capacityFactor = (1 - item.outputStockRatio).clamp(0.0, 1.0);
    for (final slot in item.slots) {
      final product = slot.product;
      if (!slot.isActive || !slot.hasProduct || product == null) continue;
      final requiresInput = product.inputProductIds.isNotEmpty;
      if (requiresInput && item.inputStockQuantity <= 0) continue;
      total += _estimatedProductionUnitValue(
        product: productsById[product.id] ?? product,
        multiplier: 1.0,
        capacityFactor: capacityFactor,
      );
    }
  }

  return total;
}

double _estimatedProductionUnitValue({
  required ProductModel product,
  required double multiplier,
  required double capacityFactor,
}) {
  final hourlyUnits = product.uretimAdedi <= 0 ? 0.0 : product.uretimAdedi.toDouble();
  if (hourlyUnits <= 0) return 0.0;
  final unitValue = _referenceProductValue(product);
  return hourlyUnits * unitValue * multiplier * capacityFactor;
}

double _referenceProductValue(ProductModel product) {
  if (product.ortalamaFiyat > 0) return product.ortalamaFiyat;
  if (product.bazSatisFiyati > 0) return product.bazSatisFiyati;
  return 0.0;
}

bool _isDefaultBrand(String brandId) {
  return brandId.isEmpty ||
      brandId == '00000000-0000-0000-0000-000000000000';
}

double _storeQualityPriceMultiplier(int qualityLevel) {
  switch (qualityLevel.clamp(1, 5)) {
    case 2:
      return 1.10;
    case 3:
      return 1.22;
    case 4:
      return 1.35;
    case 5:
      return 1.50;
    default:
      return 1.00;
  }
}

double _storePriceDemandMultiplier({
  required double price,
  required double referencePrice,
}) {
  if (referencePrice <= 0) return 1.0;

  final ratio = price / referencePrice;
  if (ratio <= 1) {
    return (1 + ((1 - ratio) * 0.75)).clamp(0.05, 1.75).toDouble();
  }

  return (1 - ((ratio - 1) * 0.95)).clamp(0.05, 1.75).toDouble();
}
