import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';

void main() {
  group('Logistics & Transfer Actions Logic Tests', () {
    test('Cargo volume & weight calculation for transfer', () {
      const itemQty = 100;
      const unitVolume = 0.4; // m3
      const unitWeight = 5.0; // kg

      final totalVolume = itemQty * unitVolume;
      final totalWeight = itemQty * unitWeight;

      expect(totalVolume, equals(40.0));
      expect(totalWeight, equals(500.0));
    });

    test('Route travel duration calculation', () {
      const distanceKm = 480.0;
      const speedKmh = 80.0;

      final travelTimeHours = distanceKm / speedKmh;
      final travelTimeMinutes = travelTimeHours * 60;

      expect(travelTimeHours, equals(6.0));
      expect(travelTimeMinutes, equals(360));
    });

    test('Logistics transfer cost calculation', () {
      const fixedCost = 250.0;
      const variableCostPerKm = 1.5;
      const distanceKm = 300.0;

      final totalCost = fixedCost + (distanceKm * variableCostPerKm);
      expect(totalCost, equals(700.0));
    });

    test('Vehicle capacity validation logic', () {
      final vehicle = ProductionLogisticsVehicleOption.fromJson({
        'vehicle_id': 'v_truck',
        'vehicle_name': 'Kamyon',
        'capacity': 30,
        'speed_kmh': 75,
        'can_select': true,
      });

      bool canFitCargo(int cargoVolume) {
        return cargoVolume <= vehicle.capacity;
      }

      expect(canFitCargo(25), isTrue);
      expect(canFitCargo(35), isFalse); // Hacim aşıldı
    });

    test('Ad speedup time reduction calculation', () {
      const initialMinutes = 120;
      const adReductionMinutes = 30;

      final remainingMinutes = (initialMinutes - adReductionMinutes).clamp(0, initialMinutes);
      expect(remainingMinutes, equals(90));
    });
  });
}
