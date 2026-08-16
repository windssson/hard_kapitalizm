import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bank Action Logic & Validation Tests', () {
    test('Loan interest calculations & installment split', () {
      const amount = 100000.0;
      const installments = 12;
      const interestRate = 0.10; // %10 faiz

      final totalRepayment = amount * (1 + interestRate);
      final monthlyPayment = totalRepayment / installments;

      expect(totalRepayment, closeTo(110000.0, 0.001));
      expect(monthlyPayment, closeTo(9166.666, 0.01));
    });

    test('Deposit maturity yield formula check', () {
      const amount = 50000.0;
      const days = 30;
      const annualRate = 0.24; // %24 yıllık faiz

      final yieldAmount = amount * annualRate * (days / 365.0);
      final totalAmount = amount + yieldAmount;

      expect(yieldAmount, closeTo(986.30, 0.1));
      expect(totalAmount, closeTo(50986.30, 0.1));
    });

    test('Early deposit withdrawal penalty calculation', () {
      const principal = 50000.0;
      const penaltyRate = 0.05; // %5 ceza

      final netAmount = principal * (1 - penaltyRate);
      expect(netAmount, closeTo(47500.0, 0.001));
    });
  });
}
