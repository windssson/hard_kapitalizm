import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Production Buildings Actions Logic Tests', () {
    group('Field (Tarla) Actions', () {
      test('Harvest yield calculation with worker and boost multipliers', () {
        const baseYield = 100;
        const workerMultiplier = 1.2; // %20 işçi verimlilik primi
        const boostMultiplier = 1.5; // %50 boost

        final totalYield = (baseYield * workerMultiplier * boostMultiplier).round();
        expect(totalYield, equals(180));
      });

      test('Field upgrade cost scaling formula', () {
        double calculateUpgradeCost(int currentLevel, double baseCost) {
          return baseCost * pow(currentLevel, 1.4);
        }

        expect(calculateUpgradeCost(1, 10000.0), equals(10000.0));
        expect(calculateUpgradeCost(2, 10000.0), closeTo(26390.1, 0.1));
      });
    });

    group('Farm (Çiftlik) Actions', () {
      test('Animal feeding raw material consumption', () {
        const animalCount = 50;
        const feedPerAnimalPerCycle = 2.0; // kg

        final totalFeedNeeded = animalCount * feedPerAnimalPerCycle;
        expect(totalFeedNeeded, equals(100.0));
      });

      test('Farm output production formula', () {
        const animalCount = 50;
        const outputPerAnimal = 3.5; // örn. Süt litresi

        final totalOutput = animalCount * outputPerAnimal;
        expect(totalOutput, equals(175.0));
      });
    });

    group('Factory (Fabrika) Actions', () {
      test('Factory input raw materials check & recipe output ratio', () {
        const targetOutputQty = 10;
        const reqMat1PerUnit = 2.0; // Demir
        const reqMat2PerUnit = 1.0; // Kömür

        final totalMat1Needed = targetOutputQty * reqMat1PerUnit;
        final totalMat2Needed = targetOutputQty * reqMat2PerUnit;

        expect(totalMat1Needed, equals(20.0));
        expect(totalMat2Needed, equals(10.0));

        bool hasSufficientStock(double availMat1, double availMat2) {
          return availMat1 >= totalMat1Needed && availMat2 >= totalMat2Needed;
        }

        expect(hasSufficientStock(25.0, 15.0), isTrue);
        expect(hasSufficientStock(15.0, 15.0), isFalse); // Mat1 yetersiz
      });

      test('Factory production duration calculation with ARGE bonus', () {
        const baseDurationSeconds = 3600; // 1 saat
        const argeSpeedBonusPct = 0.20; // %20 hızlandırma

        final actualDurationSeconds = (baseDurationSeconds / (1 + argeSpeedBonusPct)).round();
        expect(actualDurationSeconds, equals(3000));
      });
    });

    group('Mine (Maden) Actions', () {
      test('Mine extraction rate per hour per level', () {
        double getExtractionRatePerHour(int mineLevel, double baseRate) {
          return baseRate * (1 + (mineLevel - 1) * 0.25);
        }

        expect(getExtractionRatePerHour(1, 200.0), equals(200.0));
        expect(getExtractionRatePerHour(3, 200.0), equals(300.0));
        expect(getExtractionRatePerHour(5, 200.0), equals(400.0));
      });
    });
  });
}
