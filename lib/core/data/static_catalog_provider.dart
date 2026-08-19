import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_type_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_type_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaticCatalogBundle {
  final List<CityModel> cities;
  final List<ProductModel> products;
  final List<StoreTypeModel> storeTypes;
  final List<Map<String, dynamic>> warehouseTypes;
  final List<Map<String, dynamic>> factoryTypes;
  final List<Map<String, dynamic>> farmTypes;
  final List<Map<String, dynamic>> fieldTypes;
  final List<Map<String, dynamic>> mineTypes;
  final List<LogisticsCompanyTypeModel> logisticsCompanyTypes;
  final List<LogisticsVehicleTypeModel> logisticsVehicleTypes;

  const StaticCatalogBundle({
    required this.cities,
    required this.products,
    required this.storeTypes,
    required this.warehouseTypes,
    required this.factoryTypes,
    required this.farmTypes,
    required this.fieldTypes,
    required this.mineTypes,
    required this.logisticsCompanyTypes,
    required this.logisticsVehicleTypes,
  });
}

final staticCatalogsProvider = FutureProvider<StaticCatalogBundle>((ref) async {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> toMapList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  try {
    final response = await supabase.rpc('get_static_catalogs_bundle');
    final bundleMap = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);

    final cityRows = toMapList(bundleMap['cities']);
    final productRows = toMapList(bundleMap['products']);
    final storeTypeRows = toMapList(bundleMap['store_types']);

    return StaticCatalogBundle(
      cities: cityRows.map(CityModel.fromJson).toList(),
      products: productRows.map(ProductModel.fromJson).toList(),
      storeTypes: storeTypeRows.map(StoreTypeModel.fromJson).toList(),
      warehouseTypes: toMapList(bundleMap['warehouse_types']),
      factoryTypes: toMapList(bundleMap['factory_types']),
      farmTypes: toMapList(bundleMap['farm_types']),
      fieldTypes: toMapList(bundleMap['field_types']),
      mineTypes: toMapList(bundleMap['mine_types']),
      logisticsCompanyTypes: toMapList(bundleMap['logistics_company_types'])
          .map(LogisticsCompanyTypeModel.fromJson)
          .toList(),
      logisticsVehicleTypes: toMapList(bundleMap['logistics_vehicle_types'])
          .map(LogisticsVehicleTypeModel.fromJson)
          .toList(),
    );
  } catch (_) {
    // Fallback to parallel multi-rpc if bundle fails
    final responses = await Future.wait([
      supabase.rpc('get_active_cities'),
      supabase.rpc('get_all_products_catalog'),
      supabase.rpc('get_store_types_catalog'),
      supabase.rpc('get_warehouse_types_catalog'),
      supabase.rpc('get_factory_types_catalog'),
      supabase.rpc('get_farm_types_catalog'),
      supabase.rpc('get_field_types_catalog'),
      supabase.rpc('get_mine_types_catalog'),
      supabase.rpc('get_logistics_company_types_catalog'),
      supabase.rpc('get_logistics_vehicle_types_catalog'),
    ]);

    final cityRows = toMapList(responses[0]);
    final productRows = toMapList(responses[1]);
    final storeTypeRows = toMapList(responses[2]);

    return StaticCatalogBundle(
      cities: cityRows.map(CityModel.fromJson).toList(),
      products: productRows.map(ProductModel.fromJson).toList(),
      storeTypes: storeTypeRows.map(StoreTypeModel.fromJson).toList(),
      warehouseTypes: toMapList(responses[3]),
      factoryTypes: toMapList(responses[4]),
      farmTypes: toMapList(responses[5]),
      fieldTypes: toMapList(responses[6]),
      mineTypes: toMapList(responses[7]),
      logisticsCompanyTypes: toMapList(responses[8])
          .map(LogisticsCompanyTypeModel.fromJson)
          .toList(),
      logisticsVehicleTypes: toMapList(responses[9])
          .map(LogisticsVehicleTypeModel.fromJson)
          .toList(),
    );
  }
});

class StaticCatalogController {
  final Ref _ref;

  StaticCatalogController(this._ref);

  Future<StaticCatalogBundle> refresh() async {
    _ref.invalidate(staticCatalogsProvider);
    return _ref.read(staticCatalogsProvider.future);
  }
}

final staticCatalogControllerProvider = Provider<StaticCatalogController>(
  (ref) => StaticCatalogController(ref),
);
