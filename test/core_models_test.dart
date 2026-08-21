import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_quote_model.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/features/bank/models/loan_model.dart';
import 'package:hard_kapitalizm/features/bank/models/deposit_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

void main() {
  group('BuildingBoostModel Tests', () {
    test('fromJson & durationLabel parsing works correctly', () {
      final now = DateTime.now();
      final finish = now.add(const Duration(hours: 2, minutes: 30));

      final json = {
        'id': 'boost_1',
        'building_kind': 'factory',
        'entity_id': 'fac_123',
        'duration_hours': 3,
        'star_cost': 10,
        'multiplier': 1.5,
        'status': 'in_progress',
        'started_at': now.toIso8601String(),
        'finish_at': finish.toIso8601String(),
        'completed_at': null,
      };

      final boost = BuildingBoostModel.fromJson(json);

      expect(boost.id, equals('boost_1'));
      expect(boost.buildingKind, equals('factory'));
      expect(boost.starCost, equals(10));
      expect(boost.multiplier, equals(1.5));
      expect(boost.isInProgress, isTrue);
      expect(boost.durationMinutes, equals(150));
      expect(boost.durationLabel, equals('2 sa 30 dk'));
    });

    test('durationLabel formats round hours correctly', () {
      final now = DateTime.now();
      final finish = now.add(const Duration(hours: 3));

      final json = {
        'id': 'boost_2',
        'building_kind': 'mine',
        'entity_id': 'mine_1',
        'duration_hours': 3,
        'star_cost': 5,
        'multiplier': 2.0,
        'status': 'in_progress',
        'started_at': now.toIso8601String(),
        'finish_at': finish.toIso8601String(),
      };

      final boost = BuildingBoostModel.fromJson(json);
      expect(boost.durationLabel, equals('3 saat'));
    });
  });

  group('ProductModel Tests', () {
    test('fromJson and toJson round-trip preserves fields', () {
      final json = {
        'id': 'PROD_DEMIR',
        'urun_adi': 'Demir Külçesi',
        'urun_iconu': 'iron_bar',
        'birim_hacim': 0.5,
        'birim_agirlik': 2.0,
        'hammadde_1_id': 'MADEN_CEVHER',
        'hammadde_1_miktar': 3.0,
        'hammadde_2_id': 'KOEVUR',
        'hammadde_2_miktar': 1.0,
        'hammadde_3_id': null,
        'hammadde_3_miktar': null,
        'uretim_birimi': 'Fabrika',
        'baz_satis_fiyati': 150.0,
        'uretim_adedi': 100,
        'satis_adedi': 80,
        'en_dusuk_fiyat': 120.0,
        'en_yuksek_fiyat': 180.0,
        'ortalama_fiyat': 155.0,
        'satici_sayisi': 5,
        'piyasadaki_stok': 1200,
        'iscilik_maliyeti': 12.5,
        'created_at': '2026-01-01T00:00:00.000Z',
        'kategori': 'Maden',
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, equals('PROD_DEMIR'));
      expect(product.urunAdi, equals('Demir Külçesi'));
      expect(product.birimHacim, equals(0.5));
      expect(product.birimAgirlik, equals(2.0));
      expect(product.inputProductIds, containsAll(['MADEN_CEVHER', 'KOEVUR']));
      expect(product.inputProductIds.length, equals(2));

      final serialized = product.toJson();
      expect(serialized['id'], equals('PROD_DEMIR'));
      expect(serialized['urun_adi'], equals('Demir Külçesi'));
      expect(serialized['kategori'], equals('Maden'));
    });
  });

  group('BuildingUpgradeQuoteModel Tests', () {
    test('fromJson parses requirements and quote data correctly', () {
      final json = {
        'can_upgrade': false,
        'block_reason': 'insufficient_funds',
        'building_kind': 'factory',
        'entity_id': 'fac_1',
        'current_level': 4,
        'target_level': 5,
        'max_level': 10,
        'cash_cost': 250000.0,
        'duration_seconds': 3600,
        'effects': [
          {'metric_key': 'capacity', 'operation': 'add', 'value': 100, 'previous_value': 400, 'next_value': 500},
        ]
      };

      final quote = BuildingUpgradeQuoteModel.fromJson(json);

      expect(quote.targetLevel, equals(5));
      expect(quote.cashCost, equals(250000.0));
      expect(quote.durationSeconds, equals(3600));
      expect(quote.effects.length, equals(1));
      expect(quote.canUpgrade, isFalse);
    });
  });

  group('ProductionLogisticsModels Tests', () {
    test('ProductionLogisticsVehicleOption Model handles vehicle data', () {
      final json = {
        'vehicle_id': 'v_1',
        'vehicle_name': 'TIR Master',
        'capacity': 40,
        'speed_kmh': 80,
        'rental_price': 500.0,
        'can_select': true,
      };

      final vehicle = ProductionLogisticsVehicleOption.fromJson(json);

      expect(vehicle.vehicleId, equals('v_1'));
      expect(vehicle.vehicleName, equals('TIR Master'));
      expect(vehicle.capacity, equals(40));
      expect(vehicle.speedKmh, equals(80));
      expect(vehicle.canSelect, isTrue);
    });
  });

  group('LoanModel & DepositModel Tests', () {
    test('LoanModel parsing and remaining calculation', () {
      final json = {
        'id': 'loan_99',
        'player_id': 'player_1',
        'amount': 100000.0,
        'interest_rate': 0.15,
        'total_due': 115000.0,
        'total_paid': 19166.66,
        'installments_total': 12,
        'installments_paid': 2,
        'installment_amount': 9583.33,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'next_installment_due_at': '2026-02-01T00:00:00.000Z',
        'status': 'active',
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.id, equals('loan_99'));
      expect(loan.amount, equals(100000.0));
      expect(loan.totalDue, equals(115000.0));
      expect(loan.installmentsTotal, equals(12));
      expect(loan.installmentsPaid, equals(2));
      expect(loan.installmentsTotal - loan.installmentsPaid, equals(10));
      expect(loan.status, equals('active'));
    });

    test('DepositModel parsing and completion check', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 10));

      final json = {
        'id': 'dep_10',
        'player_id': 'player_1',
        'amount': 50000.0,
        'interest_rate': 0.20,
        'expected_payout': 60000.0,
        'created_at': past.toIso8601String(),
        'updated_at': past.toIso8601String(),
        'locked_until': past.add(const Duration(days: 30)).toIso8601String(),
        'status': 'active',
      };

      final deposit = DepositModel.fromJson(json);

      expect(deposit.id, equals('dep_10'));
      expect(deposit.amount, equals(50000.0));
      expect(deposit.expectedPayout, equals(60000.0));
      expect(deposit.status, equals('active'));
      expect(deposit.lockedUntil.isBefore(now), isFalse);
    });
  });

  group('BrandCompany & City Models Tests', () {
    test('BrandCompanyModel parses brand parameters properly', () {
      final json = {
        'id': 'brand_77',
        'player_id': 'player_1',
        'brand_name': 'Hard Holding',
        'logo_id': 'lion_gold',
        'theme_color': '#FFD700',
        'brand_xp': 2500,
        'brand_level': 3,
      };

      final brand = BrandCompanyModel.fromJson(json);

      expect(brand.id, equals('brand_77'));
      expect(brand.brandName, equals('Hard Holding'));
      expect(brand.brandLevel, equals(3));
      expect(brand.brandXp, equals(2500));
    });

    test('CityModel parses city attributes properly', () {
      final json = {
        'id': 'city_ist',
        'name': 'İstanbul',
        'population': 16000000,
        'tax_rate': 0.12,
        'map_position_x': 10.0,
        'map_position_y': 20.0,
        'is_active': true,
      };

      final city = CityModel.fromJson(json);

      expect(city.id, equals('city_ist'));
      expect(city.name, equals('İstanbul'));
      expect(city.taxRate, equals(0.12));
      expect(city.isActive, isTrue);
    });

    test('PlayerModel parses headquartersCityId and headquartersCityName properly', () {
      final json = {
        'id': 'p_123',
        'player_name': 'Test Patron',
        'company_name': 'Patron Holding',
        'avatar_id': 'ae1.webp',
        'headquarters_city_id': '9d78fceb-3a67-4913-864f-95d7c6dc064e',
        'headquarters_city_name': 'İstanbul',
        'level': 2,
        'experience': 500,
        'cash': 250000.0,
        'gold': 150.0,
        'company_value': 1000000.0,
      };

      final player = PlayerModel.fromJson(json);

      expect(player.id, equals('p_123'));
      expect(player.headquartersCityId, equals('9d78fceb-3a67-4913-864f-95d7c6dc064e'));
      expect(player.headquartersCityName, equals('İstanbul'));
      expect(player.level, equals(2));

      final updated = player.copyWith(
        headquartersCityId: 'city_ankara',
        headquartersCityName: 'Ankara',
      );
      expect(updated.headquartersCityId, equals('city_ankara'));
      expect(updated.headquartersCityName, equals('Ankara'));
    });
  });
}
