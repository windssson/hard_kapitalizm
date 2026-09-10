import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/building_construction_quote_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_quote_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/core/models/slot_unlock_quote_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

void main() {
  test('factory and mine parse slot counts', () {
    final factory = FactoryModel.fromJson({
      'id': 'factory-1',
      'player_id': 'player-1',
      'factory_type_id': 'type-1',
      'city_id': 'city-1',
      'name': 'Test Factory',
      'level': 2,
      'quality_level': 0,
      'current_slot_count': 2,
      'max_slot_count': 5,
      'input_capacity': 100,
      'output_capacity': 200,
      'boost_multiplier': 1,
      'is_active': true,
      'created_at': '2026-09-10T12:00:00Z',
      'updated_at': '2026-09-10T12:00:00Z',
    });
    final mine = MineModel.fromJson({
      'id': 'mine-1',
      'player_id': 'player-1',
      'mine_type_id': 'type-1',
      'city_id': 'city-1',
      'name': 'Test Mine',
      'level': 1,
      'quality_level': 0,
      'current_slot_count': 3,
      'max_slot_count': 5,
      'output_capacity': 100,
      'boost_multiplier': 1,
      'is_active': true,
      'created_at': '2026-09-10T12:00:00Z',
      'updated_at': '2026-09-10T12:00:00Z',
    });

    expect(factory.currentSlotCount, 2);
    expect(factory.maxSlotCount, 5);
    expect(mine.currentSlotCount, 3);
    expect(mine.maxSlotCount, 5);
  });

  test('production slot contract parses new slot source of truth', () {
    final slot = ProductionSlotContractModel.fromJson({
      'id': 'slot-2',
      'owner_kind': 'factory',
      'owner_id': 'factory-1',
      'slot_index': 2,
      'product_id': 'GUBRE',
      'brand_id': 'brand-1',
      'quality_level': 4,
      'boost_multiplier': 2,
      'is_active': true,
      'last_production_at': '2026-09-10T12:00:00Z',
    });

    expect(slot.ownerKind, 'factory');
    expect(slot.slotIndex, 2);
    expect(slot.productId, 'GUBRE');
    expect(slot.brandId, 'brand-1');
    expect(slot.isConfigured, isTrue);
    expect(slot.lastProductionAt, isNotNull);
  });

  test('construction quote parses material and cash requirements', () {
    final quote = BuildingConstructionQuoteModel.fromJson({
      'success': true,
      'can_construct': false,
      'block_reason': 'materials',
      'city_id': 'city-1',
      'building_kind': 'store',
      'building_type_id': 'type-1',
      'name': 'Manav',
      'cash_cost': 30000,
      'player_cash': 50000,
      'has_required_cash': true,
      'required_player_level': 1,
      'duration_minutes': 10,
      'required_materials': [
        {
          'product_id': 'BETON',
          'product_name': 'Beton',
          'product_icon': 'beton.webp',
          'required_quantity': 10,
          'available_quantity': 4,
          'missing_quantity': 6,
          'has_enough': false,
        },
      ],
      'materials_all_met': false,
      'material_source': 'city_general_warehouse',
      'material_source_city_id': 'city-1',
      'construction_materials_exempt': false,
      'completed_due_constructions': 0,
    });

    expect(quote.canConstruct, isFalse);
    expect(quote.hasRequiredCash, isTrue);
    expect(quote.requiredMaterials.single.missingQuantity, 6);
    expect(quote.materialsAllMet, isFalse);
  });

  test('upgrade quote parses new material, cash and tax fields', () {
    final quote = BuildingUpgradeQuoteModel.fromJson({
      'can_upgrade': false,
      'block_reason': 'tax_blocked',
      'building_kind': 'factory',
      'entity_id': 'factory-1',
      'current_level': 1,
      'target_level': 2,
      'max_level': 5,
      'required_player_level': 2,
      'cash_cost': 750000,
      'player_cash': 900000,
      'has_required_cash': true,
      'tax_blocked': true,
      'duration_seconds': 3600,
      'effects': [],
      'required_materials': [],
      'has_required_materials': true,
      'material_source_city_id': 'city-1',
      'material_source': 'city_general_warehouse',
      'completed_due_upgrades': 0,
    });

    expect(quote.taxBlocked, isTrue);
    expect(quote.hasRequiredCash, isTrue);
    expect(quote.requirementLabel, contains('Vergi'));
  });

  test('slot unlock quote parses paid slot contract', () {
    final quote = SlotUnlockQuoteModel.fromJson({
      'success': true,
      'can_unlock': true,
      'block_reason': null,
      'building_kind': 'factory',
      'entity_id': 'factory-1',
      'building_type_id': 'type-1',
      'name': 'Gıda İşleme Fabrikası',
      'current_slot_count': 1,
      'max_slot_count': 3,
      'next_slot_index': 2,
      'cash_cost': 100000,
      'player_cash': 500000,
      'has_required_cash': true,
      'tax_blocked': false,
    });

    expect(quote.canUnlock, isTrue);
    expect(quote.nextSlotIndex, 2);
    expect(quote.cashCost, 100000);
  });
}
