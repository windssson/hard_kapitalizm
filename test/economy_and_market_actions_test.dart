import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Economy, Market, Store & Warehouse Actions Logic Tests', () {
    group('Market (Pazar) Actions', () {
      test('Market buy total cost calculation', () {
        const qty = 50;
        const unitPrice = 120.0;
        final totalCost = qty * unitPrice;

        expect(totalCost, equals(6000.0));
      });

      test('Market sell net revenue after market tax deduction', () {
        const qty = 100;
        const unitPrice = 200.0;
        const marketTaxRate = 0.05; // %5 pazar vergisi

        final grossRevenue = qty * unitPrice;
        final netRevenue = grossRevenue * (1 - marketTaxRate);

        expect(grossRevenue, equals(20000.0));
        expect(netRevenue, equals(19000.0));
      });
    });

    group('Store (Mağaza) Actions', () {
      test('Store product price bounds validation', () {
        const minPrice = 50.0;
        const maxPrice = 250.0;

        bool isPriceValid(double price) {
          return price >= minPrice && price <= maxPrice;
        }

        expect(isPriceValid(150.0), isTrue);
        expect(isPriceValid(30.0), isFalse);
        expect(isPriceValid(300.0), isFalse);
      });

      test('Store stock usage percentage calculation', () {
        const currentStockVolume = 450.0;
        const storeCapacityVolume = 500.0;

        final usagePercentage = (currentStockVolume / storeCapacityVolume) * 100;
        expect(usagePercentage, equals(90.0));
      });
    });

    group('Warehouse (Depo) Actions', () {
      test('Warehouse capacity check when adding new items', () {
        const currentVolume = 800.0;
        const maxCapacity = 1000.0;

        bool canStore(double incomingVolume) {
          return (currentVolume + incomingVolume) <= maxCapacity;
        }

        expect(canStore(150.0), isTrue);
        expect(canStore(250.0), isFalse);
      });

      test('Warehouse target stock deficiency calculation', () {
        const targetStock = 500;
        const currentStock = 320;

        final deficit = (targetStock - currentStock).clamp(0, targetStock);
        expect(deficit, equals(180));
      });
    });
  });
}
