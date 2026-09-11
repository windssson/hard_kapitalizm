import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/data/store_warehouse_insert_patch_service.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

void main() {
  final catalogs = StaticCatalogBundle(
    cities: [
      CityModel(
        id: 'istanbul',
        name: 'İstanbul',
        population: 1,
        taxRate: 0,
        mapPositionX: 0,
        mapPositionY: 0,
        isActive: true,
        categoryBonuses: const {},
      ),
    ],
    products: const [],
    storeTypes: [
      StoreTypeModel(
        id: 'manav',
        name: 'Manav',
        icon: 'manav.webp',
      ),
    ],
    warehouseTypes: const [
      {'id': 'general', 'name': 'Genel Depo', 'icon': 'warehouse.webp'},
    ],
    factoryTypes: const [],
    farmTypes: const [],
    fieldTypes: const [],
    mineTypes: const [],
    logisticsCompanyTypes: const [],
    logisticsVehicleTypes: const [],
  );

  test('store insert resolves city and store type metadata', () {
    final metadata = resolveStoreWarehouseInsertMetadata(
      catalogs: catalogs,
      entity: 'store',
      changes: const {
        'city_id': 'istanbul',
        'store_type_id': 'manav',
      },
    );

    expect(metadata, isNotNull);
    expect(metadata!.city.name, 'İstanbul');
    expect(metadata.storeType?.name, 'Manav');
    expect(metadata.storeType?.icon, 'manav.webp');
  });

  test('warehouse insert resolves city and warehouse type metadata', () {
    final metadata = resolveStoreWarehouseInsertMetadata(
      catalogs: catalogs,
      entity: 'warehouse',
      changes: const {
        'city_id': 'istanbul',
        'warehouse_type_id': 'general',
      },
    );

    expect(metadata, isNotNull);
    expect(metadata!.city.name, 'İstanbul');
    expect(metadata.warehouseType?['name'], 'Genel Depo');
    expect(metadata.warehouseType?['icon'], 'warehouse.webp');
  });

  test('missing type metadata returns null instead of empty model', () {
    final metadata = resolveStoreWarehouseInsertMetadata(
      catalogs: catalogs,
      entity: 'store',
      changes: const {
        'city_id': 'istanbul',
        'store_type_id': 'missing',
      },
    );

    expect(metadata, isNull);
  });
}
