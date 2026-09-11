import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/production_building_insert_patch_service.dart';

void main() {
  test('production building metadata type is constructible', () {
    const metadata = ProductionBuildingPatchMetadata(
      cityName: 'İstanbul',
      typeName: 'Gıda İşleme Fabrikası',
      typeIcon: 'food.webp',
    );

    expect(metadata.cityName, 'İstanbul');
    expect(metadata.typeName, isNotEmpty);
    expect(metadata.typeIcon, endsWith('.webp'));
  });
}
