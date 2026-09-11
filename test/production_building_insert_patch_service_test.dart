import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/production_building_insert_patch_service.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';

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
    storeTypes: const [],
    warehouseTypes: const [],
    factoryTypes: const [
      {'id': 'factory-type', 'name': 'Gıda İşleme Fabrikası', 'icon': 'food.webp'},
    ],
    farmTypes: const [
      {'id': 'farm-type', 'name': 'Sebze Tarlası', 'icon': 'field.webp'},
    ],
    fieldTypes: const [
      {'id': 'field-type', 'name': 'Kümes Hayvancılığı', 'icon': 'coop.webp'},
    ],
    mineTypes: const [
      {'id': 'mine-type', 'name': 'Taş Ocağı', 'icon': 'quarry.webp'},
    ],
    logisticsCompanyTypes: const [],
    logisticsVehicleTypes: const [],
  );

  test('factory insert metadata resolves from static catalogs', () {
    final metadata = resolveProductionBuildingPatchMetadata(
      catalogs: catalogs,
      entity: 'factory',
      changes: const {
        'city_id': 'istanbul',
        'factory_type_id': 'factory-type',
      },
    );

    expect(metadata, isNotNull);
    expect(metadata!.cityName, 'İstanbul');
    expect(metadata.typeName, 'Gıda İşleme Fabrikası');
    expect(metadata.typeIcon, 'food.webp');
  });

  test('all production building kinds resolve their own type catalog', () {
    final mine = resolveProductionBuildingPatchMetadata(
      catalogs: catalogs,
      entity: 'mine',
      changes: const {'city_id': 'istanbul', 'mine_type_id': 'mine-type'},
    );
    final field = resolveProductionBuildingPatchMetadata(
      catalogs: catalogs,
      entity: 'field',
      changes: const {'city_id': 'istanbul', 'field_type_id': 'field-type'},
    );
    final farm = resolveProductionBuildingPatchMetadata(
      catalogs: catalogs,
      entity: 'farm',
      changes: const {'city_id': 'istanbul', 'farm_type_id': 'farm-type'},
    );

    expect(mine?.typeName, 'Taş Ocağı');
    expect(field?.typeName, 'Kümes Hayvancılığı');
    expect(farm?.typeName, 'Sebze Tarlası');
  });

  test('missing metadata returns null instead of a placeholder', () {
    final metadata = resolveProductionBuildingPatchMetadata(
      catalogs: catalogs,
      entity: 'factory',
      changes: const {
        'city_id': 'istanbul',
        'factory_type_id': 'missing-type',
      },
    );

    expect(metadata, isNull);
  });
}
