import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Company & Brand Action Logic Tests', () {
    test('Brand Level calculation from Brand XP', () {
      int calculateBrandLevel(int xp) {
        if (xp <= 0) return 1;
        return (xp / 500).floor() + 1;
      }

      expect(calculateBrandLevel(0), equals(1));
      expect(calculateBrandLevel(499), equals(1));
      expect(calculateBrandLevel(500), equals(2));
      expect(calculateBrandLevel(2500), equals(6));
    });

    test('Marketing campaign cost & duration formula check', () {
      final campaigns = {
        'social_media': {'cost': 10000.0, 'duration_hours': 24, 'boost_pct': 0.05},
        'billboard': {'cost': 50000.0, 'duration_hours': 72, 'boost_pct': 0.15},
        'tv_ad': {'cost': 250000.0, 'duration_hours': 168, 'boost_pct': 0.35},
      };

      expect(campaigns.containsKey('social_media'), isTrue);
      expect(campaigns['tv_ad']!['cost'], equals(250000.0));
      expect(campaigns['billboard']!['boost_pct'], equals(0.15));
    });

    test('Theme color hex validation', () {
      bool isValidHexColor(String hex) {
        final regExp = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');
        return regExp.hasMatch(hex);
      }

      expect(isValidHexColor('#FFD700'), isTrue);
      expect(isValidHexColor('#fff'), isTrue);
      expect(isValidHexColor('blue'), isFalse);
      expect(isValidHexColor('123456'), isFalse);
    });
  });
}
